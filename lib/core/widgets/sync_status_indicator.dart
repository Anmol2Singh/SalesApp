// lib/core/widgets/sync_status_indicator.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/offline_queue_service.dart';
import '../providers/connectivity_provider.dart';

class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final syncStatus = ref.watch(syncStatusProvider);

    Color color;
    String tooltip;

    if (!isOnline) {
      color = Colors.amber;
      tooltip = 'Offline / Changes will sync when online';
    } else {
      switch (syncStatus) {
        case SyncStatus.online:
          color = Colors.green;
          tooltip = 'Connected & Synced';
          break;
        case SyncStatus.offline:
          color = Colors.amber;
          tooltip = 'Syncing offline queue...';
          break;
        case SyncStatus.error:
          color = Colors.red;
          tooltip = 'Sync Error';
          break;
      }
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.5),
              blurRadius: 6,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}
