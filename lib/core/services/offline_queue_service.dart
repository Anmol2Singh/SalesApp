// lib/core/services/offline_queue_service.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/supabase_provider.dart';

final offlineQueueProvider = Provider<OfflineQueueService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return OfflineQueueService(supabase);
});

final syncStatusProvider = StateProvider<SyncStatus>((ref) => SyncStatus.online);

enum SyncStatus { online, offline, error }

class OfflineQueueService {
  final SupabaseClient _supabase;
  OfflineQueueService(this._supabase);

  Box get _box => Hive.box('offline_write_queue');

  bool get hasPendingSync => _box.isNotEmpty;

  List<Map<String, dynamic>> get queue {
    return _box.values.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> queueWrite(String action, Map<String, dynamic> data) async {
    await _box.add({
      'action': action,
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    debugPrint("Queued offline write operation: $action");
  }

  Future<bool> processQueue(WidgetRef ref) async {
    if (_box.isEmpty) return true;
    ref.read(syncStatusProvider.notifier).state = SyncStatus.offline; // Syncing indicator
    debugPrint("Processing offline write queue of size ${_box.length}...");

    final items = List.from(_box.keys);
    bool success = true;

    for (final key in items) {
      final item = Map<String, dynamic>.from(_box.get(key) as Map);
      final action = item['action'] as String;
      final data = Map<String, dynamic>.from(item['data'] as Map);

      try {
        if (action == 'create_customer') {
          await _supabase.from('customers').insert(data);
        } else if (action == 'update_pipeline_step') {
          await _supabase.from('sales_pipelines').update(data).eq('id', data['id']);
        }
        await _box.delete(key);
        debugPrint("Successfully synced offline write: $action");
      } catch (e) {
        debugPrint("Failed to sync offline write: $e");
        success = false;
        ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
        break; // Stop processing queue on error to maintain order
      }
    }

    if (success) {
      ref.read(syncStatusProvider.notifier).state = SyncStatus.online;
    }
    return success;
  }
}
