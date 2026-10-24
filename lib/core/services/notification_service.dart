// lib/core/services/notification_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../router/app_router.dart';
import '../providers/supabase_provider.dart';
import '../../features/auth/providers/auth_provider.dart';

const String kNotificationChannelId = 'izyheat_sales_updates';
const String kNotificationChannelName = 'IZYHEAT Sales Updates';
const String kNotificationChannelDesc =
    'Realtime push notifications for Quotations, BOQs, Factory Orders, and Purchase Orders';

/// Top-level background message handler for FCM
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  debugPrint('🔔 [FCM Background] Message received: ${message.messageId}, data: ${message.data}');
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static StreamSubscription<String>? _tokenRefreshSubscription;
  static bool _isInitialized = false;

  /// Initialize Firebase, FCM, and Local Notifications
  static Future<void> init() async {
    if (_isInitialized) return;
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      _isInitialized = true;
      return;
    }

    try {
      // 1. Initialize Firebase SDK
      await Firebase.initializeApp();

      // 2. Set background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 3. Setup Android Notification Channel
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        kNotificationChannelId,
        kNotificationChannelName,
        description: kNotificationChannelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(channel);
      }

      // 4. Initialize flutter_local_notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _notificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          _handlePayloadString(response.payload);
        },
      );

      // 5. Request permissions (Android 13+ runtime permission & iOS)
      await requestPermissions();

      // 6. Handle foreground FCM messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('🔔 [FCM Foreground] Message received: ${message.notification?.title}');
        final notification = message.notification;
        final title = notification?.title ?? message.data['title'] ?? 'IZYHEAT Update';
        final body = notification?.body ?? message.data['body'] ?? '';
        final payload = jsonEncode(message.data);

        showNotification(
          id: message.messageId?.hashCode ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000),
          title: title,
          body: body,
          payload: payload,
        );
      });

      // 7. Handle notification taps when app opened from background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('🔔 [FCM Tap] App opened from background: ${message.data}');
        handleNavigation(message.data);
      });

      // 8. Handle notification tap when app opened from terminated state
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('🔔 [FCM Tap] App opened from terminated: ${initialMessage.data}');
        // Wait briefly for router and view tree to finish initializing
        Future.delayed(const Duration(milliseconds: 600), () {
          handleNavigation(initialMessage.data);
        });
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('⚠️ [NotificationService] Initialization error: $e');
    }
  }

  /// Request runtime notification permissions (Android 13+ and iOS)
  static Future<void> requestPermissions() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('Notification permission request error: $e');
    }
  }

  /// Display a local notification via flutter_local_notifications
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      kNotificationChannelId,
      kNotificationChannelName,
      channelDescription: kNotificationChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: payload,
    );
  }

  /// Parse payload and deep link using GoRouter
  static void handleNavigation(Map<String, dynamic> data) {
    final navContext = rootNavigatorKey.currentContext;
    if (navContext == null) {
      Future.delayed(const Duration(milliseconds: 400), () => handleNavigation(data));
      return;
    }

    final pipelineId = data['pipeline_id'] ?? data['related_pipeline_id'];
    final step = (data['step'] ?? '').toString().toLowerCase();
    final amcId = data['amc_id'] ?? data['related_amc_id'];

    if (pipelineId != null && pipelineId.toString().isNotEmpty) {
      final pId = pipelineId.toString();
      if (step == 'quotation') {
        navContext.push(AppRoutes.quotationForm.replaceAll(':id', pId));
      } else if (step == 'sales_order') {
        navContext.push(AppRoutes.salesOrderForm.replaceAll(':id', pId));
      } else if (step == 'boq') {
        navContext.push(AppRoutes.boqForm.replaceAll(':id', pId));
      } else if (step == 'factory' || step == 'factory_order') {
        navContext.push(AppRoutes.factoryOrderForm.replaceAll(':id', pId));
      } else if (step == 'purchase' || step == 'purchase_order') {
        navContext.push(AppRoutes.purchaseOrderForm.replaceAll(':id', pId));
      } else {
        navContext.push(AppRoutes.pipelineDetail.replaceAll(':id', pId));
      }
      return;
    }

    if (amcId != null && amcId.toString().isNotEmpty) {
      navContext.push('/amc/details/${amcId.toString()}');
      return;
    }

    // Default route
    navContext.push(AppRoutes.notifications);
  }

  static void _handlePayloadString(String? payload) {
    if (payload == null || payload.isEmpty) {
      final navContext = rootNavigatorKey.currentContext;
      if (navContext != null) navContext.push(AppRoutes.notifications);
      return;
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        handleNavigation(decoded);
        return;
      }
    } catch (_) {}

    // Fallback: If payload was directly a pipeline ID
    handleNavigation({'pipeline_id': payload});
  }

  /// Get current device FCM token
  static Future<String?> getDeviceToken() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('⚠️ Error getting device FCM token: $e');
      return null;
    }
  }

  /// Upsert device FCM token into Supabase fcm_tokens table
  static Future<void> registerDeviceToken(
    SupabaseClient supabase,
    String userId,
  ) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    try {
      final token = await getDeviceToken();
      if (token != null && token.isNotEmpty) {
        await supabase.from('fcm_tokens').upsert(
          {
            'user_id': userId,
            'token': token,
            'platform': Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other'),
            'updated_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'token',
        );
        debugPrint('✅ [FCM] Device token registered in Supabase for user $userId');
      }

      // Listen for token refreshes
      _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription =
          FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        try {
          await supabase.from('fcm_tokens').upsert(
            {
              'user_id': userId,
              'token': newToken,
              'platform': Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other'),
              'updated_at': DateTime.now().toIso8601String(),
            },
            onConflict: 'token',
          );
          debugPrint('🔄 [FCM] Device token refreshed in Supabase');
        } catch (e) {
          debugPrint('⚠️ [FCM] Token refresh save failed: $e');
        }
      });
    } catch (e) {
      debugPrint('⚠️ [FCM] Register device token error: $e');
    }
  }

  /// Remove device token on logout
  static Future<void> unregisterDeviceToken(SupabaseClient supabase) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    try {
      _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = null;

      final token = await getDeviceToken();
      if (token != null && token.isNotEmpty) {
        await supabase.from('fcm_tokens').delete().eq('token', token);
        debugPrint('🗑️ [FCM] Device token removed from Supabase');
      }
    } catch (e) {
      debugPrint('⚠️ [FCM] Unregister device token error: $e');
    }
  }
}

/// Riverpod provider for NotificationService
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Riverpod provider to automatically manage FCM token lifecycle on login
final fcmTokenLifecycleProvider = Provider<void>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final profile = ref.watch(currentProfileProvider);

  if (profile != null && profile.id.isNotEmpty) {
    NotificationService.registerDeviceToken(supabase, profile.id);
  }
});
