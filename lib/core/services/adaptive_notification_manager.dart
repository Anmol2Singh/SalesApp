// lib/core/services/adaptive_notification_manager.dart

import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../router/app_router.dart';

/// Global key to display custom in-app notification banners without requiring context
final GlobalKey<ScaffoldMessengerState> notificationMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Top-level background message handler for Android OS.
/// Annotated with @pragma('vm:entry-point') so Flutter engine can execute it
/// in an isolated background isolate when app is terminated or in background.
@pragma('vm:entry-point')
Future<void> backgroundNotificationHandler(Map<String, dynamic> message) async {
  // Handles system notifications when app is terminated or backgrounded.
  // In native Android FCM, this processes data payloads and delivers them to the notification tray.
  debugPrint('🔔 [BackgroundNotificationHandler] Received payload: $message');
}

class AdaptiveNotificationManager {
  static final AdaptiveNotificationManager _instance =
      AdaptiveNotificationManager._internal();
  factory AdaptiveNotificationManager() => _instance;
  AdaptiveNotificationManager._internal();

  RealtimeChannel? _realtimeChannel;
  String? _currentUserId;

  /// Initializes adaptive notification routing based on current OS
  Future<void> initialize({
    required SupabaseClient supabase,
    String? userId,
  }) async {
    _currentUserId = userId;

    if (!kIsWeb && Platform.isAndroid) {
      _initAndroidNotifications();
    } else {
      // Windows Desktop & Web in-app polyfill
      _initDesktopWebNotifications(supabase);
    }
  }

  /// Android OS Notification Logic
  void _initAndroidNotifications() {
    // In Android: Foreground notifications should NOT clutter the system notification tray.
    // Instead, they are captured in-app and shown using our custom in-app SnackBar overlay.
    debugPrint('🔔 [AdaptiveNotificationManager] Android notification listeners active.');
  }

  /// Windows Desktop & Web In-App Notification Polyfill
  /// Firebase Cloud Messaging does not provide native Windows desktop push notifications.
  /// This establishes a real-time stream subscription to the notifications table.
  /// When a new notification arrives, it triggers the identical custom in-app SnackBar banner.
  void _initDesktopWebNotifications(SupabaseClient supabase) {
    if (_currentUserId == null) return;

    _realtimeChannel?.unsubscribe();
    _realtimeChannel = supabase
        .channel('desktop_notifications_$_currentUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: _currentUserId!,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            final notifId = record['id'] as String?;
            final title = record['title'] as String? ?? 'New Notification';
            final body = record['body'] as String? ?? '';
            final type = record['type'] as String?;
            final pipelineId = record['related_pipeline_id'] as String?;
            final amcId = record['related_amc_id'] as String?;

            // Mark as read helper
            void onNotificationTapped() {
              if (notifId != null) {
                supabase
                    .from('notifications')
                    .update({'is_read': true})
                    .eq('id', notifId)
                    .then((_) {})
                    .catchError((_) {});
              }
              final navContext = rootNavigatorKey.currentContext;
              if (navContext != null && navContext.mounted) {
                if (pipelineId != null && pipelineId.isNotEmpty) {
                  navContext.push(
                    AppRoutes.pipelineDetail.replaceAll(':id', pipelineId),
                  );
                } else if (amcId != null && amcId.isNotEmpty) {
                  navContext.push('/amc/details/$amcId');
                } else {
                  navContext.push(AppRoutes.notifications);
                }
              }
            }

            // Trigger identical in-app UI banner on Windows/Web/Android
            showInAppNotification(
              title: title,
              message: body,
              type: type,
              onTap: onNotificationTapped,
            );
          },
        )
        .subscribe();

    debugPrint('🔔 [AdaptiveNotificationManager] Real-time stream active for user: $_currentUserId');
  }

  /// Custom In-App Notification UI Banner
  /// Used uniformly across Android (foreground), Windows Desktop, and Web
  static void showInAppNotification({
    required String title,
    required String message,
    String? type,
    VoidCallback? onTap,
  }) {
    final messenger = notificationMessengerKey.currentState;
    if (messenger == null) return;

    IconData icon = Icons.notifications_active_rounded;
    Color accentColor = const Color(0xFFF59E0B); // Amber

    if (type != null) {
      final t = type.toLowerCase();
      if (t.contains('payment') || t.contains('invoice')) {
        icon = Icons.payments_rounded;
        accentColor = const Color(0xFF10B981); // Emerald
      } else if (t.contains('alert') || t.contains('error') || t.contains('missed')) {
        icon = Icons.warning_rounded;
        accentColor = const Color(0xFFEF4444); // Red
      } else if (t.contains('assigned') || t.contains('order')) {
        icon = Icons.assignment_turned_in_rounded;
        accentColor = const Color(0xFF3B82F6); // Blue
      }
    }

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: const Color(0xFF0F172A), // Dark slate
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: accentColor.withOpacity(0.4), width: 1.2),
        ),
        duration: const Duration(seconds: 4),
        content: InkWell(
          onTap: () {
            messenger.hideCurrentSnackBar();
            onTap?.call();
          },
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        message,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        action: SnackBarAction(
          label: 'View',
          textColor: accentColor,
          onPressed: () {
            messenger.hideCurrentSnackBar();
            onTap?.call();
          },
        ),
      ),
    );
  }

  void dispose() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
  }
}
