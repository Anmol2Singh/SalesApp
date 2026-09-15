import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // Load environment variables
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Fallback if .env is missing in release asset bundle
  }

  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? 'https://dnhbtkhcjpkthvyhyzmt.supabase.co';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRuaGJ0a2hjanBrdGh2eWh5em10Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIwNTQxODgsImV4cCI6MjA5NzYzMDE4OH0.oMh-wN5YgqnxTBy_KOvNCQIhPu1G2xwFnfkdwaN81u8';

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
