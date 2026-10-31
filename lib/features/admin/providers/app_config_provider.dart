import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/supabase_provider.dart';

class AppConfigState {
  final bool isProductAddUnlocked;
  final DateTime? expiresAt;
  final String autoLockMode; // '15m', '1h', '4h', 'first_product', 'manual'
  final DateTime? updatedAt;
  final String? updatedBy;
  final bool isLoading;

  const AppConfigState({
    this.isProductAddUnlocked = false,
    this.expiresAt,
    this.autoLockMode = 'manual',
    this.updatedAt,
    this.updatedBy,
    this.isLoading = false,
  });

  AppConfigState copyWith({
    bool? isProductAddUnlocked,
    DateTime? expiresAt,
    String? autoLockMode,
    DateTime? updatedAt,
    String? updatedBy,
    bool? isLoading,
  }) {
    return AppConfigState(
      isProductAddUnlocked: isProductAddUnlocked ?? this.isProductAddUnlocked,
      expiresAt: expiresAt ?? this.expiresAt,
      autoLockMode: autoLockMode ?? this.autoLockMode,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final appConfigProvider = StateNotifierProvider<AppConfigNotifier, AppConfigState>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return AppConfigNotifier(supabase);
});

final productAddUnlockedProvider = Provider<bool>((ref) {
  return ref.watch(appConfigProvider).isProductAddUnlocked;
});

class AppConfigNotifier extends StateNotifier<AppConfigState> {
  final SupabaseClient _supabase;
  RealtimeChannel? _channel;

  AppConfigNotifier(this._supabase) : super(const AppConfigState()) {
    fetchConfig();
    _initRealtime();
  }

  void _initRealtime() {
    try {
      _channel = _supabase
          .channel('app_config_realtime_${DateTime.now().millisecondsSinceEpoch}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'app_config',
            callback: (payload) {
              fetchConfig();
            },
          )
          .subscribe();
    } catch (_) {}
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> fetchConfig() async {
    try {
      final res = await _supabase
          .from('app_config')
          .select()
          .eq('key', 'product_add_unlocked')
          .maybeSingle();

      if (res != null) {
        final val = res['value'];
        final bool isUnlocked = val == true || val == 'true' || val == 1 || (val is Map && val['unlocked'] == true);
        final expStr = res['expires_at'] as String?;
        final exp = expStr != null ? DateTime.tryParse(expStr) : null;

        // Check client-side expiration
        final now = DateTime.now();
        final bool actuallyUnlocked = isUnlocked && (exp == null || exp.isAfter(now));

        state = AppConfigState(
          isProductAddUnlocked: actuallyUnlocked,
          expiresAt: exp,
          autoLockMode: (res['auto_lock_mode'] as String?) ?? 'manual',
          updatedAt: res['updated_at'] != null ? DateTime.tryParse(res['updated_at']) : null,
          updatedBy: res['updated_by'] as String?,
          isLoading: false,
        );
      }
    } catch (e) {
      // If table not yet migrated, default to locked for safety
      state = state.copyWith(isProductAddUnlocked: false, isLoading: false);
    }
  }

  Future<bool> setProductAddLock({
    required bool unlock,
    required String autoLockMode, // '15m', '1h', '4h', 'first_product', 'manual'
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      DateTime? expiresAt;
      final now = DateTime.now();
      if (unlock) {
        if (autoLockMode == '15m') {
          expiresAt = now.add(const Duration(minutes: 15));
        } else if (autoLockMode == '1h') {
          expiresAt = now.add(const Duration(hours: 1));
        } else if (autoLockMode == '4h') {
          expiresAt = now.add(const Duration(hours: 4));
        }
      }

      final userId = _supabase.auth.currentUser?.id;

      await _supabase.from('app_config').upsert({
        'key': 'product_add_unlocked',
        'value': unlock,
        'auto_lock_mode': autoLockMode,
        'expires_at': expiresAt?.toIso8601String(),
        'updated_by': userId,
        'updated_at': now.toIso8601String(),
      });

      await fetchConfig();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }
}

// Audit logs provider
final appConfigAuditProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  try {
    final res = await supabase
        .from('app_config_audit')
        .select('*, changer:profiles!app_config_audit_changed_by_fkey(full_name)')
        .eq('config_key', 'product_add_unlocked')
        .order('changed_at', ascending: false)
        .limit(10);
    return List<Map<String, dynamic>>.from(res as List);
  } catch (e) {
    try {
      final res = await supabase
          .from('app_config_audit')
          .select('*')
          .eq('config_key', 'product_add_unlocked')
          .order('changed_at', ascending: false)
          .limit(10);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (_) {
      return [];
    }
  }
});

