import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'core/config/app_config.dart';
import 'core/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();

  // Catch unhandled asynchronous Flutter framework & platform errors gracefully
  // (e.g., Supabase Auth background token refresh when offline or host lookup fails)
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    final errStr = error.toString().toLowerCase();
    if (error is AuthRetryableFetchException ||
        error is SocketException ||
        errStr.contains('socketexception') ||
        errStr.contains('failed host lookup') ||
        errStr.contains('authretryablefetchexception') ||
        errStr.contains('clientexception') ||
        errStr.contains('network') ||
        errStr.contains('timed out')) {
      debugPrint('Gracefully caught offline/network error on launch: $error');
      return true; // Handled, prevents app termination
    }
    return false;
  };

  await Hive.initFlutter();
  await Hive.openBox('offline_write_queue');

  const supabaseUrl = AppConfig.supabaseUrl;
  const supabaseAnonKey = AppConfig.supabaseAnonKey;

  // Initialize Supabase gracefully with try/catch for offline launch
  try {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
      realtimeClientOptions: const RealtimeClientOptions(
        logLevel: RealtimeLogLevel.info,
      ),
    );
  } on SocketException catch (e) {
    debugPrint('Supabase initialization SocketException (offline mode): $e');
  } on AuthRetryableFetchException catch (e) {
    debugPrint('Supabase initialization AuthRetryableFetchException (offline mode): $e');
  } catch (e) {
    debugPrint('Supabase initialization network/offline exception: $e');
  }

  runApp(
    const ProviderScope(
      child: IzyheatApp(),
    ),
  );
}
