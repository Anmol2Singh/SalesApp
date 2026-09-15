// lib/features/crm/providers/crm_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/prospect_model.dart';
import '../data/models/lead_model.dart';
import '../data/models/communication_model.dart';
import '../../../core/models/user_role.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../auth/providers/auth_provider.dart';

// --- PROSPECTS ---

final prospectsProvider = StateNotifierProvider<ProspectsNotifier, AsyncValue<List<Prospect>>>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final profile = ref.watch(currentProfileProvider);
  final isAdmin = profile?.primaryRole == UserRole.admin ||
      profile?.primaryRole == UserRole.manager ||
      (profile?.roles.contains(UserRole.admin) ?? false);
  return ProspectsNotifier(supabase, profile?.id, isAdmin);
});

class ProspectsNotifier extends StateNotifier<AsyncValue<List<Prospect>>> {
  final SupabaseClient _supabase;
  final String? _userId;
  final bool _isAdmin;
  RealtimeChannel? _realtimeChannel;

  ProspectsNotifier(this._supabase, this._userId, this._isAdmin) : super(const AsyncValue.loading()) {
    load();
    _initRealtime();
  }

  void _initRealtime() {
    try {
      _realtimeChannel = _supabase
          .channel('crm_prospects_realtime_${DateTime.now().millisecondsSinceEpoch}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'crm_prospects',
            callback: (payload) {
              load();
            },
          )
          .subscribe();
    } catch (_) {}
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> load({bool refresh = false}) async {
    if (refresh && !state.hasValue) state = const AsyncValue.loading();
    try {
      dynamic query = _supabase.from('crm_prospects').select();

      // Non-admins see only their own prospects or assigned to them
      if (!_isAdmin && _userId != null) {
        query = query.or('created_by.eq.$_userId,assigned_to.eq.$_userId');
      }

      query = query.order('created_at', ascending: false);
      final List<dynamic> response = await query;
      final rawList = List<Map<String, dynamic>>.from(response);

      final userIds = <String>{};
      for (final r in rawList) {
        if (r['created_by'] != null) userIds.add(r['created_by'] as String);
        if (r['assigned_to'] != null) userIds.add(r['assigned_to'] as String);
      }

      final profileMap = <String, Map<String, dynamic>>{};
      if (userIds.isNotEmpty) {
        try {
          final profiles = await _supabase
              .from('profiles')
              .select('id, full_name, role, roles')
              .inFilter('id', userIds.toList());
          for (final p in (profiles as List)) {
            profileMap[p['id'] as String] = Map<String, dynamic>.from(p as Map);
          }
        } catch (_) {
          try {
            final profiles = await _supabase
                .from('profiles')
                .select('id, full_name')
                .inFilter('id', userIds.toList());
            for (final p in (profiles as List)) {
              profileMap[p['id'] as String] = Map<String, dynamic>.from(p as Map);
            }
          } catch (_) {}
        }
      }

      final prospects = rawList.map((json) {
        final creatorId = json['created_by'] as String?;
        final assigneeId = json['assigned_to'] as String?;
        final creatorProf = creatorId != null ? profileMap[creatorId] : null;
        final assigneeProf = assigneeId != null ? profileMap[assigneeId] : null;

        return Prospect.fromJson({
          ...json,
          'creator': creatorProf,
          'creator_name': creatorProf?['full_name'],
          'creator_role': creatorProf?['role'],
          'assignee': assigneeProf,
          'assignee_name': assigneeProf?['full_name'],
        });
      }).toList();

      state = AsyncValue.data(prospects);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> assignProspect({required String prospectId, required String salesUserId}) async {
    String? cleanNotes;
    try {
      final pRow = await _supabase.from('crm_prospects').select('notes').eq('id', prospectId).maybeSingle();
      if (pRow != null && pRow['notes'] != null) {
        final rawNotes = pRow['notes'] as String;
        cleanNotes = rawNotes
            .replaceAll(RegExp(r'\[REASSIGNMENT_REQUEST:[^\]]*\]'), '')
            .replaceAll(RegExp(r'\n\s*\n'), '\n')
            .trim();
      }
    } catch (_) {}

    final updateData = <String, dynamic>{
      'assigned_to': salesUserId,
      'reassignment_requested': false,
      'reassignment_reason': null,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (cleanNotes != null) {
      updateData['notes'] = cleanNotes;
    }

    try {
      await _supabase.from('crm_prospects').update(updateData).eq('id', prospectId);
    } catch (_) {
      await _supabase.from('crm_prospects').update({
        'assigned_to': salesUserId,
        if (cleanNotes != null) 'notes': cleanNotes,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', prospectId);
    }

    try {
      await _supabase.from('notifications').insert({
        'user_id': salesUserId,
        'title': 'New Prospect Assigned 🎯',
        'body': 'A prospect has been assigned to you. Check CRM to follow up.',
        'type': 'prospect_assigned',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}

    await load();
  }

  Future<void> requestTransfer({
    required String prospectId,
    String? reason,
    String? prospectName,
  }) async {
    final note = reason ?? 'Requested by salesperson';

    // 1. Update prospect record
    try {
      await _supabase.from('crm_prospects').update({
        'reassignment_requested': true,
        'reassignment_reason': note,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', prospectId);
    } catch (_) {
      try {
        final current = await _supabase.from('crm_prospects').select('notes').eq('id', prospectId).maybeSingle();
        final existingNotes = current?['notes'] as String? ?? '';
        final newNotes = '$existingNotes\n[REASSIGNMENT_REQUEST: $note]'.trim();
        await _supabase.from('crm_prospects').update({'notes': newNotes}).eq('id', prospectId);
      } catch (_) {}
    }

    // 2. Notify Admins
    try {
      final staffResponse = await _supabase.from('profiles').select('id, role, roles');
      final adminIds = <String>{};
      for (final s in (staffResponse as List? ?? [])) {
        final role = (s['role'] as String? ?? '').toLowerCase();
        final rolesList = (s['roles'] is List) ? (s['roles'] as List).map((e) => e.toString().toLowerCase()).toList() : [];
        if (role == 'admin' || role == 'manager' || role == 'sales_head' ||
            rolesList.contains('admin') || rolesList.contains('manager') || rolesList.contains('sales_head')) {
          if (s['id'] != null) adminIds.add(s['id'] as String);
        }
      }

      for (final aid in adminIds) {
        await _supabase.from('notifications').insert({
          'user_id': aid,
          'title': 'Prospect Reassignment Requested ⚠️',
          'body': 'Sales rep requested reassignment for prospect "${prospectName ?? 'Prospect'}". Reason: $note',
          'type': 'prospect_transfer_request',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {}

    await load();
  }

  Future<void> cancelReassignmentRequest({
    required String prospectId,
    String? prospectName,
  }) async {
    try {
      await _supabase.from('crm_prospects').update({
        'reassignment_requested': false,
        'reassignment_reason': 'Request Cancelled by Salesperson',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', prospectId);
    } catch (_) {
      try {
        final current = await _supabase.from('crm_prospects').select('notes').eq('id', prospectId).maybeSingle();
        final existingNotes = (current?['notes'] as String? ?? '')
            .replaceAll(RegExp(r'\[REASSIGNMENT_REQUEST:[^\]]*\]'), '')
            .trim();
        final newNotes = '$existingNotes\n[REASSIGNMENT_CANCELLED]'.trim();
        await _supabase.from('crm_prospects').update({'notes': newNotes}).eq('id', prospectId);
      } catch (_) {}
    }

    try {
      final staffResponse = await _supabase.from('profiles').select('id, role, roles');
      final adminIds = <String>{};
      for (final s in (staffResponse as List? ?? [])) {
        final role = (s['role'] as String? ?? '').toLowerCase();
        final rolesList = (s['roles'] is List) ? (s['roles'] as List).map((e) => e.toString().toLowerCase()).toList() : [];
        if (role == 'admin' || role == 'manager' || role == 'sales_head' ||
            rolesList.contains('admin') || rolesList.contains('manager') || rolesList.contains('sales_head')) {
          if (s['id'] != null) adminIds.add(s['id'] as String);
        }
      }

      for (final aid in adminIds) {
        await _supabase.from('notifications').insert({
          'user_id': aid,
          'title': 'Prospect Reassignment Cancelled ℹ️',
          'body': 'Sales rep cancelled the reassignment request for prospect "${prospectName ?? 'Prospect'}".',
          'type': 'prospect_transfer_cancelled',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {}

    await load();
  }

  Future<Prospect?> addProspect({
    required String name,
    required String phone,
    String? email,
    String? address,
    String? gst,
    String? company,
    String source = 'Manual',
    String? notes,
  }) async {
    if (_userId == null) return null;
    try {
      final data = {
        'name': name.trim(),
        'phone': phone.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (address != null && address.trim().isNotEmpty) 'address': address.trim(),
        if (gst != null && gst.trim().isNotEmpty) 'gst': gst.trim(),
        if (company != null && company.trim().isNotEmpty) 'company': company.trim(),
        'source': source,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        'created_by': _userId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase.from('crm_prospects').insert(data).select().single();
      final newProspect = Prospect.fromJson(response);
      await load();
      return newProspect;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateProspect({
    required String prospectId,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? gst,
    String? company,
    String? source,
    String? notes,
  }) async {
    final data = <String, dynamic>{
      if (name != null) 'name': name.trim(),
      if (phone != null) 'phone': phone.trim(),
      if (email != null) 'email': email.trim(),
      if (address != null) 'address': address.trim(),
      if (gst != null) 'gst': gst.trim(),
      if (company != null) 'company': company.trim(),
      if (source != null) 'source': source,
      if (notes != null) 'notes': notes.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    await _supabase.from('crm_prospects').update(data).eq('id', prospectId);
    await load();
  }

  Future<void> deleteProspect({
    required String prospectId,
    bool deleteCustomer = false,
    String? customerId,
  }) async {
    try {
      if (deleteCustomer && customerId != null && customerId.isNotEmpty) {
        try {
          await _supabase.from('customers').delete().eq('id', customerId);
        } catch (_) {}
      }

      try {
        await _supabase.from('crm_leads').delete().eq('prospect_id', prospectId);
      } catch (_) {}

      await _supabase.from('crm_prospects').delete().eq('id', prospectId);
      await load();
    } catch (e) {
      rethrow;
    }
  }

  Future<String?> convertToLead({
    required String prospectId,
    required String prospectName,
    required String contactPhone,
    required String productName,
    required double estimatedValue,
    DateTime? expectedDate,
    String? notes,
    String? capacity,
    List<Map<String, dynamic>>? components,
  }) async {
    if (_userId == null) return null;
    try {
      String? converterName;
      try {
        final p = await _supabase.from('profiles').select('full_name').eq('id', _userId).single();
        converterName = p['full_name'] as String?;
      } catch (_) {}

      // Carry forward assigned salesperson from prospect if present
      final prospectRecord = state.value?.where((p) => p.id == prospectId).firstOrNull;
      final assignedSalesperson = prospectRecord?.assignedTo;

      final leadData = {
        'prospect_id': prospectId,
        'prospect_name': prospectName,
        'contact_phone': contactPhone,
        'product_name': productName.trim(),
        'estimated_value': estimatedValue,
        if (expectedDate != null) 'expected_date': expectedDate.toIso8601String(),
        'status': 'New',
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        if (capacity != null && capacity.trim().isNotEmpty) 'capacity': capacity.trim(),
        if (components != null && components.isNotEmpty) 'components': components,
        if (assignedSalesperson != null) 'assigned_to': assignedSalesperson,
        'converted_by': _userId,
        if (converterName != null) 'converted_by_name': converterName,
        'created_by': _userId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final leadRes = await _supabase.from('crm_leads').insert(leadData).select().single();
      final leadId = leadRes['id'] as String;

      // Update prospect
      await _supabase.from('crm_prospects').update({
        'converted_to_lead_id': leadId,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', prospectId);

      await load();
      return leadId;
    } catch (e) {
      rethrow;
    }
  }
}

final prospectByIdProvider = Provider.family<Prospect?, String>((ref, id) {
  final prospectsAsync = ref.watch(prospectsProvider);
  return prospectsAsync.value?.where((p) => p.id == id).firstOrNull;
});

// --- LEADS ---

final leadsProvider = StateNotifierProvider<LeadsNotifier, AsyncValue<List<Lead>>>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final profile = ref.watch(currentProfileProvider);
  final isAdmin = profile?.primaryRole == UserRole.admin ||
      profile?.primaryRole == UserRole.manager ||
      (profile?.roles.contains(UserRole.admin) ?? false);
  return LeadsNotifier(supabase, profile?.id, isAdmin);
});

class LeadsNotifier extends StateNotifier<AsyncValue<List<Lead>>> {
  final SupabaseClient _supabase;
  final String? _userId;
  final bool _isAdmin;
  RealtimeChannel? _realtimeChannel;

  LeadsNotifier(this._supabase, this._userId, this._isAdmin) : super(const AsyncValue.loading()) {
    load();
    _initRealtime();
  }

  void _initRealtime() {
    try {
      _realtimeChannel = _supabase
          .channel('crm_leads_realtime_${DateTime.now().millisecondsSinceEpoch}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'crm_leads',
            callback: (payload) {
              load();
            },
          )
          .subscribe();
    } catch (_) {}
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> load({bool refresh = false}) async {
    if (refresh && !state.hasValue) state = const AsyncValue.loading();
    try {
      dynamic query = _supabase.from('crm_leads').select();

      if (!_isAdmin && _userId != null) {
        query = query.or('created_by.eq.$_userId,assigned_to.eq.$_userId');
      }

      query = query.order('created_at', ascending: false);
      final List<dynamic> response = await query;

      final userIds = <String>{};
      for (final r in response) {
        if (r['created_by'] != null) userIds.add(r['created_by'] as String);
        if (r['assigned_to'] != null) userIds.add(r['assigned_to'] as String);
      }

      Map<String, Map<String, dynamic>> profilesMap = {};
      if (userIds.isNotEmpty) {
        try {
          final profs = await _supabase
              .from('profiles')
              .select('id, full_name, role, roles')
              .inFilter('id', userIds.toList());
          for (final p in (profs as List? ?? [])) {
            profilesMap[p['id'] as String] = Map<String, dynamic>.from(p as Map);
          }
        } catch (_) {
          try {
            final profs = await _supabase
                .from('profiles')
                .select('id, full_name')
                .inFilter('id', userIds.toList());
            for (final p in (profs as List? ?? [])) {
              profilesMap[p['id'] as String] = Map<String, dynamic>.from(p as Map);
            }
          } catch (_) {}
        }
      }

      final leads = response.map((json) {
        final creatorProf = profilesMap[json['created_by']];
        final assigneeProf = profilesMap[json['assigned_to']];

        return Lead.fromJson({
          ...(json as Map<String, dynamic>),
          'creator': creatorProf,
          'creator_name': creatorProf?['full_name'],
          'assignee': assigneeProf,
          'assignee_name': assigneeProf?['full_name'],
        });
      }).toList();
      state = AsyncValue.data(leads);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Lead?> addDirectLead({
    required String prospectName,
    String? contactPhone,
    required String productName,
    required double estimatedValue,
    DateTime? expectedDate,
    String? notes,
  }) async {
    if (_userId == null) return null;
    try {
      // 1. Optionally create a prospect record or direct lead
      String? prospectId;
      if (contactPhone != null && contactPhone.trim().isNotEmpty) {
        try {
          final prospectRes = await _supabase.from('crm_prospects').insert({
            'name': prospectName.trim(),
            'phone': contactPhone.trim(),
            'source': 'Manual',
            'created_by': _userId,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          }).select().single();
          prospectId = prospectRes['id'] as String;
        } catch (_) {}
      }

      final leadData = {
        if (prospectId != null) 'prospect_id': prospectId,
        'prospect_name': prospectName.trim(),
        if (contactPhone != null) 'contact_phone': contactPhone.trim(),
        'product_name': productName.trim(),
        'estimated_value': estimatedValue,
        if (expectedDate != null) 'expected_date': expectedDate.toIso8601String(),
        'status': 'New',
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        'created_by': _userId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final leadRes = await _supabase.from('crm_leads').insert(leadData).select().single();
      final newLead = Lead.fromJson(leadRes);

      if (prospectId != null) {
        await _supabase.from('crm_prospects').update({
          'converted_to_lead_id': newLead.id,
        }).eq('id', prospectId);
      }

      await load();
      return newLead;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateStatus(String leadId, String status) async {
    try {
      await _supabase.from('crm_leads').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', leadId);
      await load();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> assignLead({required String leadId, required String salesUserId}) async {
    String? cleanNotes;
    try {
      final lRow = await _supabase.from('crm_leads').select('notes').eq('id', leadId).maybeSingle();
      if (lRow != null && lRow['notes'] != null) {
        final rawNotes = lRow['notes'] as String;
        cleanNotes = rawNotes
            .replaceAll(RegExp(r'\[REASSIGNMENT_REQUEST:[^\]]*\]'), '')
            .replaceAll(RegExp(r'\n\s*\n'), '\n')
            .trim();
      }
    } catch (_) {}

    final updateData = <String, dynamic>{
      'assigned_to': salesUserId,
      'reassignment_requested': false,
      'reassignment_reason': null,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (cleanNotes != null) {
      updateData['notes'] = cleanNotes;
    }

    try {
      await _supabase.from('crm_leads').update(updateData).eq('id', leadId);
    } catch (_) {
      await _supabase.from('crm_leads').update({
        'assigned_to': salesUserId,
        if (cleanNotes != null) 'notes': cleanNotes,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', leadId);
    }

    try {
      await _supabase.from('notifications').insert({
        'user_id': salesUserId,
        'title': 'New Lead Assigned 🎯',
        'body': 'A lead has been assigned to you. Check CRM to follow up.',
        'type': 'lead_assigned',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}

    await load();
  }

  Future<void> requestTransfer({
    required String leadId,
    String? reason,
    String? leadName,
  }) async {
    final note = reason ?? 'Requested by salesperson';

    // 1. Update lead record
    try {
      await _supabase.from('crm_leads').update({
        'reassignment_requested': true,
        'reassignment_reason': note,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', leadId);
    } catch (_) {
      try {
        final current = await _supabase.from('crm_leads').select('notes').eq('id', leadId).maybeSingle();
        final existingNotes = current?['notes'] as String? ?? '';
        final newNotes = '$existingNotes\n[REASSIGNMENT_REQUEST: $note]'.trim();
        await _supabase.from('crm_leads').update({'notes': newNotes}).eq('id', leadId);
      } catch (_) {}
    }

    // 2. Notify Admins
    try {
      final staffResponse = await _supabase.from('profiles').select('id, role, roles');
      final adminIds = <String>{};
      for (final s in (staffResponse as List? ?? [])) {
        final role = (s['role'] as String? ?? '').toLowerCase();
        final rolesList = (s['roles'] is List) ? (s['roles'] as List).map((e) => e.toString().toLowerCase()).toList() : [];
        if (role == 'admin' || role == 'manager' || role == 'sales_head' ||
            rolesList.contains('admin') || rolesList.contains('manager') || rolesList.contains('sales_head')) {
          if (s['id'] != null) adminIds.add(s['id'] as String);
        }
      }

      for (final aid in adminIds) {
        await _supabase.from('notifications').insert({
          'user_id': aid,
          'title': 'Lead Reassignment Requested ⚠️',
          'body': 'Sales rep requested reassignment for lead "${leadName ?? 'Lead'}". Reason: $note',
          'type': 'lead_transfer_request',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {}

    await load();
  }

  Future<void> cancelTransfer({
    required String leadId,
    String? leadName,
  }) async {
    try {
      await _supabase.from('crm_leads').update({
        'reassignment_requested': false,
        'reassignment_reason': 'Request Cancelled by Salesperson',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', leadId);
    } catch (_) {
      try {
        final current = await _supabase.from('crm_leads').select('notes').eq('id', leadId).maybeSingle();
        final existingNotes = (current?['notes'] as String? ?? '')
            .replaceAll(RegExp(r'\[REASSIGNMENT_REQUEST:[^\]]*\]'), '')
            .trim();
        final newNotes = '$existingNotes\n[REASSIGNMENT_CANCELLED]'.trim();
        await _supabase.from('crm_leads').update({'notes': newNotes}).eq('id', leadId);
      } catch (_) {}
    }

    try {
      final staffResponse = await _supabase.from('profiles').select('id, role, roles');
      final adminIds = <String>{};
      for (final s in (staffResponse as List? ?? [])) {
        final role = (s['role'] as String? ?? '').toLowerCase();
        final rolesList = (s['roles'] is List) ? (s['roles'] as List).map((e) => e.toString().toLowerCase()).toList() : [];
        if (role == 'admin' || role == 'manager' || role == 'sales_head' ||
            rolesList.contains('admin') || rolesList.contains('manager') || rolesList.contains('sales_head')) {
          if (s['id'] != null) adminIds.add(s['id'] as String);
        }
      }

      for (final aid in adminIds) {
        await _supabase.from('notifications').insert({
          'user_id': aid,
          'title': 'Lead Reassignment Cancelled ℹ️',
          'body': 'Sales rep cancelled the reassignment request for lead "${leadName ?? 'Lead'}".',
          'type': 'lead_transfer_cancelled',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {}

    await load();
  }

  Future<void> updateLead({
    required String leadId,
    String? prospectName,
    String? contactPhone,
    String? productName,
    double? estimatedValue,
    DateTime? expectedDate,
    String? status,
    String? notes,
    String? capacity,
    List<Map<String, dynamic>>? components,
    DateTime? reminderDate,
    String? reminderNote,
  }) async {
    final data = <String, dynamic>{
      if (prospectName != null) 'prospect_name': prospectName.trim(),
      if (contactPhone != null) 'contact_phone': contactPhone.trim(),
      if (productName != null) 'product_name': productName.trim(),
      if (estimatedValue != null) 'estimated_value': estimatedValue,
      if (expectedDate != null) 'expected_date': expectedDate.toIso8601String(),
      if (status != null) 'status': status,
      if (notes != null) 'notes': notes.trim(),
      if (capacity != null) 'capacity': capacity.trim(),
      if (components != null) 'components': components,
      if (reminderDate != null) 'reminder_date': reminderDate.toUtc().toIso8601String(),
      if (reminderNote != null) 'reminder_note': reminderNote.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (estimatedValue != null) {
      final currentLeads = state.value ?? [];
      final existingLead = currentLeads.where((l) => l.id == leadId).firstOrNull;
      if (existingLead != null &&
          existingLead.estimatedValue != estimatedValue &&
          existingLead.status != 'Won' &&
          existingLead.status != 'Lost') {
        data['status'] = 'Negotiating';
      }
    }

    await _supabase.from('crm_leads').update(data).eq('id', leadId);
    await load();
  }

  Future<void> setReminder({
    required String leadId,
    required DateTime reminderDate,
    String? reminderNote,
  }) async {
    final utcDate = reminderDate.toUtc();
    await _supabase.from('crm_leads').update({
      'reminder_date': utcDate.toIso8601String(),
      if (reminderNote != null) 'reminder_note': reminderNote.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', leadId);
    await load();
  }

  Future<void> addReminder({
    required String leadId,
    required DateTime reminderDate,
    String? reminderNote,
  }) async {
    final utcDate = reminderDate.toUtc();
    final newReminder = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'date_time': utcDate.toIso8601String(),
      'note': reminderNote?.trim() ?? '',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    final currentLeads = state.value ?? [];
    final currentLead = currentLeads.where((l) => l.id == leadId).firstOrNull;
    final List<dynamic> currentReminders = currentLead?.reminders != null
        ? List<dynamic>.from(currentLead!.reminders)
        : [];
    currentReminders.add(newReminder);

    await _supabase.from('crm_leads').update({
      'reminders': currentReminders,
      'reminder_date': utcDate.toIso8601String(),
      if (reminderNote != null) 'reminder_note': reminderNote.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', leadId);
    await load();
  }

  Future<void> deleteReminder({
    required String leadId,
    required String reminderId,
  }) async {
    final currentLeads = state.value ?? [];
    final currentLead = currentLeads.where((l) => l.id == leadId).firstOrNull;
    final List<dynamic> currentReminders = currentLead?.reminders != null
        ? List<dynamic>.from(currentLead!.reminders)
        : [];
    currentReminders.removeWhere((r) => r is Map && r['id'] == reminderId);

    DateTime? nextDate;
    String? nextNote;
    for (final r in currentReminders) {
      if (r is Map && r['date_time'] != null) {
        final d = DateTime.tryParse(r['date_time'].toString());
        if (d != null && (nextDate == null || d.isBefore(nextDate))) {
          nextDate = d;
          nextNote = r['note']?.toString();
        }
      }
    }

    await _supabase.from('crm_leads').update({
      'reminders': currentReminders,
      'reminder_date': nextDate?.toIso8601String(),
      'reminder_note': nextNote,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', leadId);
    await load();
  }

  Future<void> deleteLead({
    required String leadId,
    bool deleteCustomer = false,
    String? customerId,
  }) async {
    try {
      if (deleteCustomer && customerId != null && customerId.isNotEmpty) {
        try {
          await _supabase.from('customers').delete().eq('id', customerId);
        } catch (_) {}
      }

      try {
        await _supabase.from('crm_communications').delete().eq('lead_id', leadId);
      } catch (_) {}

      try {
        await _supabase.from('quotations').delete().eq('lead_id', leadId);
      } catch (_) {}

      // Reset converted_to_lead_id on any prospect linked to this lead
      try {
        await _supabase
            .from('crm_prospects')
            .update({'converted_to_lead_id': null})
            .eq('converted_to_lead_id', leadId);
      } catch (_) {}

      await _supabase.from('crm_leads').delete().eq('id', leadId);
      await load();
    } catch (e) {
      rethrow;
    }
  }

  Future<String?> convertToCustomer({
    required String leadId,
    required String customerName,
    required String phone,
    String? email,
    String? address,
    String? gstNumber,
    String? notes,
  }) async {
    if (_userId == null) return null;
    try {
      // Get current user's full name
      String? staffName;
      try {
        final prof = await _supabase.from('profiles').select('full_name').eq('id', _userId).maybeSingle();
        staffName = prof?['full_name'] as String?;
      } catch (_) {}

      // Find current lead for assignee
      final currentLead = (state.value ?? []).where((l) => l.id == leadId).firstOrNull;

      // 1. Insert into customers table
      final customerData = {
        'customer_name': customerName.trim(),
        'company_name': customerName.trim(),
        'contact_person': customerName.trim(),
        'phone': phone.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (address != null && address.trim().isNotEmpty) 'address': address.trim(),
        if (gstNumber != null && gstNumber.trim().isNotEmpty) 'gst_number': gstNumber.trim(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        'created_by': _userId,
        if (currentLead?.assignedTo != null) 'assigned_to': currentLead!.assignedTo,
        'converted_by': _userId,
        'converted_by_name': staffName ?? 'Staff',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final custRes = await _supabase.from('customers').insert(customerData).select().single();
      final customerId = custRes['id'] as String;

      // 2. Lookup product_id
      String? productId;
      if (currentLead?.productName != null && currentLead!.productName.isNotEmpty) {
        try {
          final prodRes = await _supabase
              .from('products')
              .select('id')
              .ilike('name', '%${currentLead.productName.trim()}%')
              .limit(1);
          if (prodRes.isNotEmpty) {
            productId = prodRes.first['id'] as String;
          }
        } catch (_) {}
      }
      if (productId == null) {
        try {
          final firstProd = await _supabase.from('products').select('id').limit(1);
          if (firstProd.isNotEmpty) {
            productId = firstProd.first['id'] as String;
          }
        } catch (_) {}
      }

      // 3. Auto-create Deal in sales_pipelines
      String? pipelineId;
      if (productId != null) {
        try {
          final pipelineRes = await _supabase.from('sales_pipelines').insert({
            'customer_id': customerId,
            'product_id': productId,
            'created_by': _userId,
            'current_step': 'sales_order',
            'status': 'in_progress',
            if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          }).select().single();
          pipelineId = pipelineRes['id'] as String;
        } catch (_) {}
      }

      // 4. Query latest quotation for the lead and link to deal
      try {
        final quots = await _supabase
            .from('quotations')
            .select('id')
            .eq('lead_id', leadId)
            .order('revision', ascending: false)
            .limit(1);
        if (quots.isNotEmpty) {
          final qId = quots.first['id'] as String;
          await _supabase.from('quotations').update({
            'is_final': true,
            'status': 'confirmed',
            if (pipelineId != null) 'pipeline_id': pipelineId,
            if (productId != null) 'product_id': productId,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', qId);
        }
      } catch (_) {}

      // 5. Update lead status to 'Won' and set converted_to_customer_id, converted_by, converted_by_name
      await _supabase.from('crm_leads').update({
        'status': 'Won',
        'converted_to_customer_id': customerId,
        'converted_by': _userId,
        'converted_by_name': staffName ?? 'Staff',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', leadId);

      await load();
      return customerId;
    } catch (e) {
      rethrow;
    }
  }
}

final leadByIdProvider = Provider.family<Lead?, String>((ref, id) {
  final leadsAsync = ref.watch(leadsProvider);
  return leadsAsync.value?.where((l) => l.id == id).firstOrNull;
});

// --- COMMUNICATIONS (FOR LEADS ONLY) ---

final leadCommunicationsProvider = StateNotifierProvider.family<LeadCommunicationsNotifier, AsyncValue<List<Communication>>, String>((ref, leadId) {
  final supabase = ref.watch(supabaseClientProvider);
  final profile = ref.watch(currentProfileProvider);
  return LeadCommunicationsNotifier(supabase, leadId, profile?.id);
});

class LeadCommunicationsNotifier extends StateNotifier<AsyncValue<List<Communication>>> {
  final SupabaseClient _supabase;
  final String leadId;
  final String? _userId;

  LeadCommunicationsNotifier(this._supabase, this.leadId, this._userId) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    try {
      final List<dynamic> response = await _supabase
          .from('crm_communications')
          .select()
          .eq('lead_id', leadId)
          .order('created_at', ascending: false);

      final logs = response.map((json) => Communication.fromJson(json as Map<String, dynamic>)).toList();
      state = AsyncValue.data(logs);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logCommunication({
    required String type,
    required String summary,
  }) async {
    if (_userId == null) return;
    try {
      final data = {
        'lead_id': leadId,
        'type': type,
        'summary': summary.trim(),
        'logged_by': _userId,
        'created_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from('crm_communications').insert(data);
      // Auto-update lead status to 'In Progress' if currently 'New'
      try {
        final leadRes = await _supabase.from('crm_leads').select('status').eq('id', leadId).maybeSingle();
        if (leadRes != null && leadRes['status'] == 'New') {
          await _supabase.from('crm_leads').update({
            'status': 'In Progress',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', leadId);
        }
      } catch (_) {}
      await load();
    } catch (e) {
      rethrow;
    }
  }
}

// --- SOURCES ---
final crmSourcesProvider = StateNotifierProvider<CrmSourcesNotifier, AsyncValue<List<String>>>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return CrmSourcesNotifier(supabase);
});

class CrmSourcesNotifier extends StateNotifier<AsyncValue<List<String>>> {
  final SupabaseClient _supabase;
  static const List<String> defaultSources = [
    'Cold Call',
    'Exhibition',
    'IndiaMart',
    'JustDial',
    'Manual',
    'Referral',
    'Social Media',
    'Walk-in',
    'Website',
    'WhatsApp',
  ];

  CrmSourcesNotifier(this._supabase) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load({bool refresh = false}) async {
    if (refresh) state = const AsyncValue.loading();
    try {
      final res = await _supabase
          .from('crm_sources')
          .select('name')
          .order('name');
      final list = (res as List)
          .map((r) => r['name'] as String)
          .where((n) => n.trim().isNotEmpty)
          .toList();
      if (list.isEmpty) {
        for (final s in defaultSources) {
          try {
            await _supabase.from('crm_sources').insert({'name': s});
          } catch (_) {}
        }
        state = const AsyncValue.data(defaultSources);
      } else {
        state = AsyncValue.data(list);
      }
    } catch (e) {
      state = const AsyncValue.data(defaultSources);
    }
  }

  Future<void> addSource(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    try {
      await _supabase.from('crm_sources').insert({'name': trimmed});
    } catch (_) {}
    await load();
  }

  Future<void> updateSource(String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    try {
      await _supabase.from('crm_sources').update({'name': trimmed}).eq('name', oldName);
    } catch (_) {}
    await load();
  }

  Future<void> deleteSource(String name) async {
    try {
      await _supabase.from('crm_sources').delete().eq('name', name);
    } catch (_) {}
    await load();
  }
}

// --- INTERACTION TYPES ---
final crmInteractionTypesProvider = StateNotifierProvider<CrmInteractionTypesNotifier, AsyncValue<List<String>>>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return CrmInteractionTypesNotifier(supabase);
});

class CrmInteractionTypesNotifier extends StateNotifier<AsyncValue<List<String>>> {
  final SupabaseClient _supabase;
  static const List<String> defaultTypes = [
    'Call',
    'WhatsApp',
    'Email',
    'Meeting',
    'Note',
    'Site Visit',
    'Demo',
  ];

  CrmInteractionTypesNotifier(this._supabase) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load({bool refresh = false}) async {
    if (refresh) state = const AsyncValue.loading();
    try {
      final res = await _supabase
          .from('crm_interaction_types')
          .select('name')
          .order('name');
      final list = (res as List)
          .map((r) => r['name'] as String)
          .where((n) => n.trim().isNotEmpty)
          .toList();
      if (list.isEmpty) {
        for (final t in defaultTypes) {
          try {
            await _supabase.from('crm_interaction_types').insert({'name': t});
          } catch (_) {}
        }
        state = const AsyncValue.data(defaultTypes);
      } else {
        state = AsyncValue.data(list);
      }
    } catch (e) {
      state = const AsyncValue.data(defaultTypes);
    }
  }

  Future<void> addType(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    try {
      await _supabase.from('crm_interaction_types').insert({'name': trimmed});
    } catch (_) {}
    await load();
  }

  Future<void> updateType(String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    try {
      await _supabase.from('crm_interaction_types').update({'name': trimmed}).eq('name', oldName);
    } catch (_) {}
    await load();
  }

  Future<void> deleteType(String name) async {
    try {
      await _supabase.from('crm_interaction_types').delete().eq('name', name);
    } catch (_) {}
    await load();
  }
}

