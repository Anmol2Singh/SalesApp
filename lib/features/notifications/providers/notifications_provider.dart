// lib/features/notifications/providers/notifications_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../core/models/notification.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../auth/providers/auth_provider.dart';

// Notifications list with realtime subscription
class NotificationsNotifier
    extends StateNotifier<AsyncValue<List<AppNotification>>> {
  final SupabaseClient _supabase;
  final String? _userId;
  RealtimeChannel? _channel;

  NotificationsNotifier(this._supabase, this._userId)
      : super(const AsyncValue.loading()) {
    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    if (supabaseUrl.contains('your-project-ref')) {
      state = const AsyncValue.data([]);
      return;
    }
    if (_userId != null) {
      _load();
      _subscribe();
    } else {
      state = const AsyncValue.data([]);
    }
  }

  Future<void> _load() async {
    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', _userId!)
          .order('created_at', ascending: false)
          .limit(50);

      final notifications = (response as List<dynamic>)
          .map((json) => AppNotification.fromJson(json as Map<String, dynamic>))
          .toList();

      state = AsyncValue.data(notifications);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _subscribe() {
    _channel = _supabase
        .channel('notifications_$_userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: _userId!,
          ),
          callback: (payload) {
            final newNotif = AppNotification.fromJson(
              payload.newRecord,
            );
            final current = state.value ?? [];
            state = AsyncValue.data([newNotif, ...current]);
          },
        )
        .subscribe();
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true}).eq('id', notificationId);

      final current = state.value ?? [];
      state = AsyncValue.data(
        current
            .map((n) => n.id == notificationId ? n.copyWith(isRead: true) : n)
            .toList(),
      );
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', _userId!)
          .eq('is_read', false);

      final current = state.value ?? [];
      state = AsyncValue.data(
        current.map((n) => n.copyWith(isRead: true)).toList(),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final notificationsNotifierProvider = StateNotifierProvider<
    NotificationsNotifier, AsyncValue<List<AppNotification>>>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final profile = ref.watch(currentProfileProvider);
  return NotificationsNotifier(supabase, profile?.id);
});

// Unread count for bell icon badge
final unreadNotificationCountProvider = Provider<AsyncValue<int>>((ref) {
  return ref.watch(notificationsNotifierProvider).whenData(
        (notifications) => notifications.where((n) => !n.isRead).length,
      );
});
