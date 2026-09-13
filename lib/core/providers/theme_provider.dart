// lib/core/providers/theme_provider.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'supabase_provider.dart';

final appThemeModeProvider = StateNotifierProvider<AppThemeModeNotifier, ThemeMode>((ref) {
  final profile = ref.watch(currentProfileProvider);
  return AppThemeModeNotifier(ref, profile?.themePreference ?? 'light');
});

class AppThemeModeNotifier extends StateNotifier<ThemeMode> {
  final Ref _ref;
  AppThemeModeNotifier(this._ref, String initialPref) : super(_parseThemeMode(initialPref));

  static ThemeMode _parseThemeMode(String pref) {
    switch (pref) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    state = mode;
    final profile = _ref.read(currentProfileProvider);
    if (profile == null) return;
    
    final prefString = mode == ThemeMode.light
        ? 'light'
        : (mode == ThemeMode.dark ? 'dark' : 'system');

    final supabase = _ref.read(supabaseClientProvider);
    try {
      if (profile.primaryRole.name == 'customer') {
        await supabase
            .from('customer_profiles')
            .update({'theme_preference': prefString})
            .eq('id', profile.id);
      } else {
        await supabase
            .from('profiles')
            .update({'theme_preference': prefString})
            .eq('id', profile.id);
      }
    } catch (e) {
      debugPrint("Error saving theme preference: $e");
    }
  }
}
