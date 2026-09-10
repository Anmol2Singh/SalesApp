import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../data/models/complaint_model.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/services/storage_service.dart';

final complaintsLoadingProvider = StateProvider<bool>((ref) => true);

class ComplaintsNotifier extends StateNotifier<List<Complaint>> {
  final Ref ref;

  ComplaintsNotifier(this.ref) : super([]) {
    _loadFromDatabase();
  }

  Future<void> _saveToLocalCache(List<Complaint> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(list.map((c) => c.toJson()).toList());
      await prefs.setString('cached_complaints_v2', encoded);
    } catch (_) {}
  }

  Future<void> _loadFromDatabase() async {
    ref.read(complaintsLoadingProvider.notifier).state = true;

    // Load from local cache first
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString('cached_complaints_v2');
      if (cachedStr != null && cachedStr.isNotEmpty) {
        final List list = jsonDecode(cachedStr);
        state = list.map((item) => Complaint.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (_) {}

    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase.from('complaints').select().order('created_at', ascending: false);
      if (response.isNotEmpty) {
        final dbComplaints = (response as List).map((json) => Complaint.fromJson(json)).toList();
        final existingIds = dbComplaints.map((c) => c.id).toSet();
        final localOnly = state.where((c) => !existingIds.contains(c.id)).toList();
        final merged = [...localOnly, ...dbComplaints];
        state = merged;
        _saveToLocalCache(merged);
      }
    } catch (_) {
    } finally {
      ref.read(complaintsLoadingProvider.notifier).state = false;
    }
  }

  Future<void> addComplaint(Complaint complaint) async {
    final validId = (complaint.id.startsWith('cmp_') || complaint.id.length < 30)
        ? const Uuid().v4()
        : complaint.id;

    String? publicImageUrl = complaint.beforeImageUrl;

    try {
      final supabase = ref.read(supabaseClientProvider);

      if (complaint.beforeImageUrl != null && complaint.beforeImageUrl!.isNotEmpty) {
        if (complaint.beforeImageUrl!.contains('|||')) {
          final items = complaint.beforeImageUrl!.split('|||');
          final urls = await StorageService.uploadMultipleImages(
            supabase: supabase,
            base64OrPaths: items,
            folder: 'issue_photos',
          );
          if (urls.isNotEmpty) publicImageUrl = urls.join('|||');
        } else if (complaint.beforeImageUrl!.startsWith('data:image')) {
          final uploaded = await StorageService.uploadImage(
            supabase: supabase,
            base64OrPath: complaint.beforeImageUrl!,
            folder: 'issue_photos',
          );
          if (uploaded != null) publicImageUrl = uploaded;
        }
      }

      final updatedComplaint = complaint.copyWith(
        id: validId,
        beforeImageUrl: publicImageUrl,
      );

      state = [updatedComplaint, ...state];
      _saveToLocalCache(state);

      await supabase.from('complaints').upsert(updatedComplaint.toJson());
    } catch (e) {
      print('Error saving complaint: $e');
    }
  }

  Future<void> assignTechnician(String complaintId, TechnicianInfo technician) async {
    state = state.map((c) {
      if (c.id == complaintId) {
        return c.copyWith(
          status: 'assigned',
          technicianId: technician.id,
          technicianName: technician.name,
          technicianAvatarUrl: technician.avatarUrl,
        );
      }
      return c;
    }).toList();
    _saveToLocalCache(state);

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('complaints').update({
        'status': 'assigned',
        'technician_name': technician.name,
        'technician_avatar_url': technician.avatarUrl,
        'technician_id': technician.id,
      }).eq('id', complaintId);
    } catch (e) {
      print('Error assigning technician in DB: $e');
    }
  }

  Future<void> completeComplaint(String complaintId, {String? beforeImage, String? afterImage}) async {
    state = state.map((c) {
      if (c.id == complaintId) {
        return c.copyWith(
          status: 'closed',
          beforeImageUrl: beforeImage ?? c.beforeImageUrl,
          afterImageUrl: afterImage ?? c.afterImageUrl,
        );
      }
      return c;
    }).toList();
    _saveToLocalCache(state);

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('complaints').update({
        'status': 'closed',
        if (beforeImage != null) 'before_image_url': beforeImage,
        if (afterImage != null) 'after_image_url': afterImage,
      }).eq('id', complaintId);
    } catch (_) {}
  }

  Future<void> saveCustomerSignature(String complaintId, String signatureUrl) async {
    state = state.map((c) {
      if (c.id == complaintId) {
        return c.copyWith(
          customerSignatureUrl: signatureUrl,
        );
      }
      return c;
    }).toList();
    _saveToLocalCache(state);

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('complaints').update({
        'customer_signature_url': signatureUrl,
      }).eq('id', complaintId);
    } catch (_) {}
  }

  Future<void> saveTechnicianSignature(String complaintId, String signatureUrl) async {
    state = state.map((c) {
      if (c.id == complaintId) {
        return c.copyWith(
          technicianSignatureUrl: signatureUrl,
        );
      }
      return c;
    }).toList();
    _saveToLocalCache(state);

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('complaints').update({
        'technician_signature_url': signatureUrl,
      }).eq('id', complaintId);
    } catch (_) {}
  }

  Future<void> updateAfterPhoto(String complaintId, String photoUrl) async {
    String? publicUrl = photoUrl;
    try {
      final supabase = ref.read(supabaseClientProvider);
      if (photoUrl.startsWith('data:image')) {
        final uploaded = await StorageService.uploadImage(
          supabase: supabase,
          base64OrPath: photoUrl,
          folder: 'issue_photos',
        );
        if (uploaded != null) publicUrl = uploaded;
      }
    } catch (_) {}

    String? newValue;
    state = state.map((c) {
      if (c.id == complaintId) {
        final existing = c.afterImageUrl;
        newValue = (existing != null && existing.isNotEmpty) ? '$existing|||$publicUrl' : publicUrl;
        return c.copyWith(
          afterImageUrl: newValue,
        );
      }
      return c;
    }).toList();
    _saveToLocalCache(state);

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('complaints').update({
        'after_image_url': newValue,
      }).eq('id', complaintId);
    } catch (_) {}
  }

  Future<void> removeAfterPhoto(String complaintId, int index) async {
    String? newValue;
    state = state.map((c) {
      if (c.id == complaintId) {
        final existing = c.afterImageUrl;
        if (existing != null && existing.isNotEmpty) {
          final parts = existing.split('|||').toList();
          if (index >= 0 && index < parts.length) {
            parts.removeAt(index);
          }
          newValue = parts.join('|||');
          if (newValue!.isEmpty) newValue = null;
        }
        return c.copyWith(afterImageUrl: newValue);
      }
      return c;
    }).toList();
    _saveToLocalCache(state);

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('complaints').update({
        'after_image_url': newValue,
      }).eq('id', complaintId);
    } catch (_) {}
  }

  Future<void> approveComplaint(String complaintId) async {
    state = state.map((c) {
      if (c.id == complaintId) {
        return c.copyWith(status: 'closed');
      }
      return c;
    }).toList();

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('complaints').update({'status': 'closed'}).eq('id', complaintId);
    } catch (_) {}
  }

  Future<void> deleteComplaint(String complaintId) async {
    state = state.where((c) => c.id != complaintId).toList();
    _saveToLocalCache(state);

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('complaints').delete().eq('id', complaintId);
    } catch (e) {
      print('Error deleting complaint: $e');
    }
  }

  Future<void> load({bool refresh = false}) async {
    await _loadFromDatabase();
  }
}

final complaintsProvider = StateNotifierProvider<ComplaintsNotifier, List<Complaint>>((ref) {
  return ComplaintsNotifier(ref);
});

final productsListProvider = FutureProvider<List<String>>((ref) async {
  try {
    final supabase = ref.watch(supabaseClientProvider);
    final response = await supabase.from('products').select('name').eq('is_active', true);
    if (response.isNotEmpty) {
      final names = (response as List).map((p) => p['name'] as String? ?? '').where((n) => n.isNotEmpty).toList();
      if (names.isNotEmpty) return names;
    }
  } catch (_) {}
  return ['Heat Pump', 'Boom Barrier', 'Solar Water Heater System'];
});

Future<String> generateNextTicketNumber(dynamic ref) async {
  final now = DateTime.now();
  final yrShort = (now.year % 100).toString();
  final nextYrShort = ((now.year + 1) % 100).toString();
  final fyPrefix = '#CMP/$yrShort-$nextYrShort/';

  try {
    final supabase = ref.read(supabaseClientProvider);
    final response = await supabase
        .from('complaints')
        .select('ticket_number')
        .like('ticket_number', '$fyPrefix%')
        .order('created_at', ascending: false)
        .limit(1);

    if (response.isNotEmpty) {
      final lastTicket = response.first['ticket_number'] as String? ?? '';
      final parts = lastTicket.split('/');
      if (parts.length == 3) {
        final lastSeq = int.tryParse(parts[2]) ?? 0;
        final nextSeq = (lastSeq + 1).toString().padLeft(4, '0');
        return '$fyPrefix$nextSeq';
      }
    }
  } catch (_) {}

  return '${fyPrefix}0001';
}

final availableTechniciansProvider = FutureProvider<List<TechnicianInfo>>((ref) async {
  List<TechnicianInfo> allTechs = [];
  try {
    final supabase = ref.watch(supabaseClientProvider);
    
    try {
      final techsResponse = await supabase.from('technicians').select();
      if (techsResponse.isNotEmpty) {
        allTechs.addAll((techsResponse as List).map((json) {
          return TechnicianInfo(
            id: json['id'] as String? ?? '',
            name: json['name'] as String? ?? 'Staff Tech',
            email: json['email'] as String?,
            phone: json['phone'] as String?,
            avatarUrl: '',
            status: json['status'] as String? ?? 'Available',
            distance: 'Nearby',
            activeTasksCount: 0,
            rating: 4.9,
          );
        }));
      }
    } catch (_) {}

    try {
      final profilesResponse = await supabase
          .from('profiles')
          .select()
          .or('role.eq.technician,roles.cs.{"technician"}');
          
      if (profilesResponse.isNotEmpty) {
        for (var json in (profilesResponse as List)) {
          final id = json['id'] as String? ?? '';
          if (!allTechs.any((t) => t.id == id)) {
            allTechs.add(TechnicianInfo(
              id: id,
              name: json['full_name'] as String? ?? 'Staff Tech',
              email: json['email'] as String?,
              phone: json['phone'] as String?,
              avatarUrl: '',
              status: 'Available',
              distance: 'Nearby',
              activeTasksCount: 0,
              rating: 4.9,
            ));
          }
        }
      }
    } catch (_) {}
    
    allTechs.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return allTechs;
  } catch (_) {
    return allTechs;
  }
});
