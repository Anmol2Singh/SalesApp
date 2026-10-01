import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/models/installation_model.dart';
import '../../complaints/data/models/complaint_model.dart' show TechnicianInfo;
import '../../../core/providers/supabase_provider.dart';
import '../../../core/services/storage_service.dart';

final installationsLoadingProvider = StateProvider<bool>((ref) => true);

class InstallationsNotifier extends StateNotifier<List<Installation>> {
  final Ref ref;

  InstallationsNotifier(this.ref) : super([]) {
    _loadFromDatabase();
  }

  Future<void> _loadFromDatabase({bool refresh = false}) async {
    ref.read(installationsLoadingProvider.notifier).state = true;

    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase
          .from('installations')
          .select()
          .order('created_at', ascending: false);
      final dbInstallations =
          (response as List).map((json) => Installation.fromJson(json)).toList();

      if (!mounted) return;
      state = dbInstallations;
    } catch (e) {
      debugPrint('Error loading installations from Supabase: $e');
    } finally {
      if (mounted) ref.read(installationsLoadingProvider.notifier).state = false;
    }
  }

  Future<void> load({bool refresh = false}) async {
    await _loadFromDatabase(refresh: refresh);
  }

  Future<void> addInstallation(Installation installation) async {
    final validId = (installation.id.startsWith('inst_') || installation.id.length < 30)
        ? const Uuid().v4()
        : installation.id;

    String? publicImageUrl = installation.beforeImageUrl;

    try {
      final supabase = ref.read(supabaseClientProvider);

      if (installation.beforeImageUrl != null &&
          installation.beforeImageUrl!.isNotEmpty) {
        if (installation.beforeImageUrl!.contains('|||')) {
          final items = installation.beforeImageUrl!.split('|||');
          final urls = await StorageService.uploadMultipleImages(
            supabase: supabase,
            base64OrPaths: items,
            folder: 'installation_photos',
          );
          if (urls.isNotEmpty) publicImageUrl = urls.join('|||');
        } else if (installation.beforeImageUrl!.startsWith('data:image')) {
          final uploaded = await StorageService.uploadImage(
            supabase: supabase,
            base64OrPath: installation.beforeImageUrl!,
            folder: 'installation_photos',
          );
          if (uploaded != null) publicImageUrl = uploaded;
        }
      }

      final updatedInstallation = installation.copyWith(
        id: validId,
        beforeImageUrl: publicImageUrl,
      );

      state = [updatedInstallation, ...state];

      await supabase
          .from('installations')
          .upsert(updatedInstallation.toJson());

      // Cross-module customer details sync
      if (updatedInstallation.customerId.isNotEmpty) {
        try {
          await supabase.from('customers').update({
            if (updatedInstallation.customerName.isNotEmpty)
              'customer_name': updatedInstallation.customerName,
            if (updatedInstallation.customerPhone.isNotEmpty)
              'phone': updatedInstallation.customerPhone,
            if (updatedInstallation.customerAddress.isNotEmpty)
              'address': updatedInstallation.customerAddress,
          }).eq('id', updatedInstallation.customerId);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error saving installation: $e');
    }
  }

  Future<void> updateInstallation(Installation updatedInstallation) async {
    state = state
        .map((i) => i.id == updatedInstallation.id ? updatedInstallation : i)
        .toList();

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase
          .from('installations')
          .update(updatedInstallation.toJson())
          .eq('id', updatedInstallation.id);

      if (updatedInstallation.customerId.isNotEmpty) {
        try {
          await supabase.from('customers').update({
            if (updatedInstallation.customerName.isNotEmpty)
              'customer_name': updatedInstallation.customerName,
            if (updatedInstallation.customerPhone.isNotEmpty)
              'phone': updatedInstallation.customerPhone,
            if (updatedInstallation.customerAddress.isNotEmpty)
              'address': updatedInstallation.customerAddress,
          }).eq('id', updatedInstallation.customerId);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error updating installation in DB: $e');
    }
  }

  Future<void> assignTechnician(
      String installationId, TechnicianInfo technician) async {
    state = state.map((i) {
      if (i.id == installationId) {
        return i.copyWith(
          status: 'assigned',
          technicianId: technician.id,
          technicianName: technician.name,
          technicianAvatarUrl: technician.avatarUrl,
        );
      }
      return i;
    }).toList();

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('installations').update({
        'status': 'assigned',
        'technician_name': technician.name,
        'technician_avatar_url': technician.avatarUrl,
        'technician_id':
            (technician.id.trim().isNotEmpty && technician.id.trim() != 'null')
                ? technician.id.trim()
                : null,
      }).eq('id', installationId);
    } catch (e) {
      debugPrint('Error assigning technician in DB: $e');
    }
  }

  Future<void> completeInstallation(String installationId,
      {String? beforeImage, String? afterImage}) async {
    state = state.map((i) {
      if (i.id == installationId) {
        return i.copyWith(
          status: 'closed',
          beforeImageUrl: beforeImage ?? i.beforeImageUrl,
          afterImageUrl: afterImage ?? i.afterImageUrl,
        );
      }
      return i;
    }).toList();

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('installations').update({
        'status': 'closed',
        if (beforeImage != null) 'before_image_url': beforeImage,
        if (afterImage != null) 'after_image_url': afterImage,
      }).eq('id', installationId);
    } catch (_) {}
  }

  Future<void> saveCustomerSignature(
      String installationId, String signatureUrl) async {
    state = state.map((i) {
      if (i.id == installationId) {
        return i.copyWith(
          customerSignatureUrl: signatureUrl,
        );
      }
      return i;
    }).toList();

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('installations').update({
        'customer_signature_url': signatureUrl,
      }).eq('id', installationId);
    } catch (_) {}
  }

  Future<void> saveTechnicianSignature(
      String installationId, String signatureUrl) async {
    state = state.map((i) {
      if (i.id == installationId) {
        return i.copyWith(
          technicianSignatureUrl: signatureUrl,
        );
      }
      return i;
    }).toList();

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('installations').update({
        'technician_signature_url': signatureUrl,
      }).eq('id', installationId);
    } catch (_) {}
  }

  Future<void> updateAfterPhoto(String installationId, String photoUrl) async {
    String? publicUrl = photoUrl;
    try {
      final supabase = ref.read(supabaseClientProvider);
      if (photoUrl.startsWith('data:image')) {
        final uploaded = await StorageService.uploadImage(
          supabase: supabase,
          base64OrPath: photoUrl,
          folder: 'installation_photos',
        );
        if (uploaded != null) publicUrl = uploaded;
      }
    } catch (_) {}

    String? newValue;
    state = state.map((i) {
      if (i.id == installationId) {
        final existing = i.afterImageUrl;
        newValue = (existing != null && existing.isNotEmpty)
            ? '$existing|||$publicUrl'
            : publicUrl;
        return i.copyWith(
          afterImageUrl: newValue,
        );
      }
      return i;
    }).toList();

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('installations').update({
        'after_image_url': newValue,
      }).eq('id', installationId);
    } catch (_) {}
  }

  Future<void> removeAfterPhoto(String installationId, int index) async {
    String? newValue;
    state = state.map((i) {
      if (i.id == installationId) {
        final existing = i.afterImageUrl;
        if (existing != null && existing.isNotEmpty) {
          final parts = existing.split('|||').toList();
          if (index >= 0 && index < parts.length) {
            parts.removeAt(index);
          }
          newValue = parts.join('|||');
          if (newValue!.isEmpty) newValue = null;
        }
        return i.copyWith(afterImageUrl: newValue);
      }
      return i;
    }).toList();

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('installations').update({
        'after_image_url': newValue,
      }).eq('id', installationId);
    } catch (_) {}
  }

  Future<void> deleteInstallation(String installationId) async {
    state = state.where((i) => i.id != installationId).toList();

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('installations').delete().eq('id', installationId);
    } catch (e) {
      debugPrint('Error deleting installation: $e');
    }
  }
}

final installationsProvider =
    StateNotifierProvider<InstallationsNotifier, List<Installation>>((ref) {
  return InstallationsNotifier(ref);
});

Future<String> generateNextInstallationTicketNumber(dynamic ref) async {
  final now = DateTime.now();
  final yrShort = (now.year % 100).toString();
  final nextYrShort = ((now.year + 1) % 100).toString();
  final fyPrefix = '#INST/$yrShort-$nextYrShort/';

  try {
    final supabase = ref.read(supabaseClientProvider);
    final response = await supabase
        .from('installations')
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
