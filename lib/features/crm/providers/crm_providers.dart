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

  ProspectsNotifier(this._supabase, this._userId, this._isAdmin) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load({bool refresh = false}) async {
    if (refresh) state = const AsyncValue.loading();
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
              .select('id, full_name, primary_role, roles')
              .inFilter('id', userIds.toList());
          for (final p in (profiles as List)) {
            profileMap[p['id'] as String] = p as Map<String, dynamic>;
          }
        } catch (_) {}
      }

      final prospects = rawList.map((json) {
        final creatorId = json['created_by'] as String?;
        final assigneeId = json['assigned_to'] as String?;
        final creatorProf = creatorId != null ? profileMap[creatorId] : null;
        final assigneeProf = assigneeId != null ? profileMap[assigneeId] : null;

        return Prospect.fromJson({
          ...json,
          'creator': creatorProf,
          'assignee': assigneeProf,
        });
      }).toList();

      state = AsyncValue.data(prospects);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> assignProspect({required String prospectId, required String salesUserId}) async {
    await _supabase.from('crm_prospects').update({
      'assigned_to': salesUserId,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', prospectId);

    try {
      await _supabase.from('notifications').insert({
        'user_id': salesUserId,
        'title': 'New Prospect Assigned by Admin 🎯',
        'body': 'Admin has assigned a new prospect to you. Check CRM to follow up.',
        'type': 'prospect_assigned',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}

    await load();
  }

  Future<void> requestTransfer({required String prospectId, String? reason}) async {
    try {
      final admins = await _supabase.from('profiles').select('id').eq('primary_role', 'admin');
      for (final a in (admins as List? ?? [])) {
        await _supabase.from('notifications').insert({
          'user_id': a['id'],
          'title': 'Prospect Transfer Requested 🔄',
          'body': 'A salesperson has requested reassignment of a prospect. ${reason != null ? "Note: $reason" : ""}',
          'type': 'prospect_transfer_request',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {}
  }

  Future<Prospect?> addProspect({
    required String name,
    required String phone,
    String? email,
    String? address,
    String? gst,
    String? company,
    String source = 'Manual',
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

  LeadsNotifier(this._supabase, this._userId, this._isAdmin) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load({bool refresh = false}) async {
    if (refresh) state = const AsyncValue.loading();
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
              .select('id, full_name, primary_role')
              .filter('id', 'in', '(${userIds.join(',')})');
          for (final p in (profs as List? ?? [])) {
            profilesMap[p['id']] = p as Map<String, dynamic>;
          }
        } catch (_) {}
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
    await _supabase.from('crm_leads').update({
      'assigned_to': salesUserId,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', leadId);

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

  Future<String?> convertToCustomer({
    required String leadId,
    required String customerName,
    required String phone,
    String? email,
    String? address,
    String? gstNumber,
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
        'contact_person': customerName.trim(),
        'phone': phone.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (address != null && address.trim().isNotEmpty) 'address': address.trim(),
        if (gstNumber != null && gstNumber.trim().isNotEmpty) 'gst_number': gstNumber.trim(),
        'created_by': _userId,
        if (currentLead?.assignedTo != null) 'assigned_to': currentLead!.assignedTo,
        'converted_by': _userId,
        'converted_by_name': staffName ?? 'Staff',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final custRes = await _supabase.from('customers').insert(customerData).select().single();
      final customerId = custRes['id'] as String;

      // 2. Update lead status to 'Won' and set converted_to_customer_id, converted_by, converted_by_name
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
    'Manual',
    'Website',
    'WhatsApp',
    'Referral',
    'Exhibition',
    'Cold Call',
    'Social Media',
    'Walk-in',
  ];

  CrmSourcesNotifier(this._supabase) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
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
        state = const AsyncValue.data(defaultSources);
      } else {
        final set = {...list, ...defaultSources};
        state = AsyncValue.data(set.toList());
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

  Future<void> deleteSource(String name) async {
    try {
      await _supabase.from('crm_sources').delete().eq('name', name);
    } catch (_) {}
    await load();
  }
}

