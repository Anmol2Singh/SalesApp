import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/models/user_role.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/customer_app/core/theme/app_theme.dart' as cust_theme;

import 'core/providers/theme_provider.dart';
import 'core/providers/connectivity_provider.dart';
import 'core/providers/realtime_provider.dart';
import 'core/services/offline_queue_service.dart';

class IzyheatApp extends ConsumerWidget {
  const IzyheatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep app-wide dynamic live updates active across all screens and roles
    ref.watch(realtimeSubscriptionProvider);

    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    final profile = ref.watch(currentProfileProvider);
    final isCustomer = profile?.primaryRole == UserRole.customer;

    // Automatically flush queue when online status is restored
    ref.listen<bool>(isOnlineProvider, (previous, next) {
      if (next == true) {
        ref.read(offlineQueueProvider).processQueue(ref);
      }
    });

    return MaterialApp.router(
      title: 'IZYHEAT',
      debugShowCheckedModeBanner: false,
      theme: isCustomer
          ? cust_theme.AppTheme.lightTheme
          : AppTheme.light.copyWith(
              textTheme: GoogleFonts.interTextTheme(AppTheme.light.textTheme),
            ),
      darkTheme: isCustomer
          ? cust_theme.AppTheme.darkTheme
          : AppTheme.dark.copyWith(
              textTheme: GoogleFonts.interTextTheme(AppTheme.dark.textTheme),
            ),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
