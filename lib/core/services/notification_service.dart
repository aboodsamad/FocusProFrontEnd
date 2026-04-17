import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Handles Firebase Cloud Messaging registration, permission, and foreground display.
/// Background messages are handled by the top-level [firebaseBackgroundHandler].
class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Call once after Firebase.initializeApp() in main().
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // ── Local notifications setup (needed for foreground display on Android) ──
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // ── Create notification channel (Android 8+) ─────────────────────────────
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          'focuspro_goals',
          'Goal Reminders',
          description: 'Smart notifications for your daily goals',
          importance: Importance.high,
        ));

    // ── Request permission ────────────────────────────────────────────────────
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('Notification permission: ${settings.authorizationStatus}');

    // ── Foreground message handler ────────────────────────────────────────────
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;
      _showLocalNotification(
        title: notification.title ?? 'FocusPro',
        body: notification.body ?? '',
        data: message.data,
      );
    });

    // ── Notification tap when app was in background ───────────────────────────
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationNavigation(message.data);
    });

    // ── Check if app was opened from a terminated-state notification ──────────
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationNavigation(initialMessage.data);
    }
  }

  /// Register FCM token with the backend. Call after user logs in.
  static Future<void> registerTokenWithBackend(String authToken) async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null || fcmToken.isEmpty) return;

      debugPrint('FCM token: $fcmToken');

      final response = await http.post(
        Uri.parse('${AuthService.baseUrl}/notifications/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'token': fcmToken}),
      );

      if (response.statusCode == 200) {
        debugPrint('FCM token registered with backend.');
      } else {
        debugPrint('FCM token registration failed: ${response.statusCode}');
      }

      // Re-register if the token refreshes (device reinstall, etc.)
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _sendTokenToBackend(newToken, authToken);
      });
    } catch (e) {
      debugPrint('registerTokenWithBackend error: $e');
    }
  }

  static Future<void> _sendTokenToBackend(String fcmToken, String authToken) async {
    try {
      await http.post(
        Uri.parse('${AuthService.baseUrl}/notifications/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'token': fcmToken}),
      );
    } catch (_) {}
  }

  static void _showLocalNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) {
    const androidDetails = AndroidNotificationDetails(
      'focuspro_goals',
      'Goal Reminders',
      channelDescription: 'Smart notifications for your daily goals',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: darwinDetails),
      payload: jsonEncode(data),
    );
  }

  static void _onNotificationTapped(NotificationResponse response) {
    if (response.payload == null) return;
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      _handleNotificationNavigation(data);
    } catch (_) {}
  }

  static void _handleNotificationNavigation(Map<String, dynamic> data) {
    // Navigate to coaching screen when user taps a goal notification
    final screen = data['screen'] as String?;
    if (screen != null && _navigatorKey != null) {
      _navigatorKey!.currentState?.pushNamed(screen);
    }
  }

  // Navigator key set from main.dart so we can navigate on notification tap
  static GlobalKey<NavigatorState>? _navigatorKey;
  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }
}

/// Top-level function required by Firebase for background message handling.
/// Must be a top-level function (not a class method).
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // Background messages are auto-displayed by Firebase on Android.
  // No additional handling needed here unless you want custom logic.
  debugPrint('Background notification received: ${message.messageId}');
}
