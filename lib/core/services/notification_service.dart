import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'browser_notification.dart';

/// Handles smart notifications for LockedIn.
///
/// On Android  : uses flutter_local_notifications (shows system tray notifications)
/// On Web      : uses VAPID Web Push + polling fallback
class NotificationService {
  static Timer? _pollTimer;
  static bool _initialized = false;
  static bool _pushSubscribed = false;

  // ── Android local notifications ──────────────────────────────────────────
  static final FlutterLocalNotificationsPlugin _localNotifs =
      FlutterLocalNotificationsPlugin();
  static bool _localNotifsReady = false;

  static const String _channelId   = 'lockedin_main';
  static const String _channelName = 'LockedIn Reminders';
  static const String _channelDesc = 'Focus session and habit reminders';

  /// Call once after login / on app start when already logged in.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    if (!kIsWeb) {
      await _initLocalNotifications();
    } else {
      // Web: ask for browser notification permission
      await BrowserNotification.requestPermission();
      if (BrowserNotification.permissionStatus != 'granted') {
        debugPrint('Notification permission not granted — skipping push setup.');
        return;
      }
      await _setupWebPush();
    }

    _startPolling();
  }

  // ── Android init ──────────────────────────────────────────────────────────

  static Future<void> _initLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifs.initialize(initSettings);

    // Create notification channel (Android 8+)
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    );
    await _localNotifs
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Request POST_NOTIFICATIONS permission (Android 13+)
    await _localNotifs
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _localNotifsReady = true;
    debugPrint('Android local notifications ready.');
  }

  // ── Web Push ──────────────────────────────────────────────────────────────

  static Future<void> _setupWebPush() async {
    final token = await AuthService.getToken();
    if (token == null) return;
    try {
      final keyResp = await http
          .get(
            Uri.parse('${AuthService.baseUrl}/notifications/vapid-public-key'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
      if (keyResp.statusCode != 200) return;
      final vapidKey =
          (jsonDecode(keyResp.body) as Map<String, dynamic>)['key'] as String? ?? '';
      if (vapidKey.isEmpty) {
        debugPrint('VAPID key not configured — using polling only.');
        return;
      }
      final subscription = await BrowserNotification.subscribeToWebPush(vapidKey);
      if (subscription == null) {
        debugPrint('Web push subscription failed — using polling only.');
        return;
      }
      final subResp = await http
          .post(
            Uri.parse('${AuthService.baseUrl}/notifications/web-push-subscribe'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(subscription),
          )
          .timeout(const Duration(seconds: 10));
      if (subResp.statusCode == 200) {
        _pushSubscribed = true;
        debugPrint('Web push subscription registered.');
      }
    } catch (e) {
      debugPrint('Web push setup error: $e');
    }
  }

  // ── Polling (both platforms) ──────────────────────────────────────────────

  static void _startPolling() {
    _pollTimer?.cancel();
    _checkForNotifications();
    int tick = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      tick++;
      if (kIsWeb && !_pushSubscribed && tick % 4 == 0) {
        await _setupWebPush();
      }
      _checkForNotifications();
    });
  }

  static Future<void> _checkForNotifications() async {
    // On web, require browser permission; on Android always proceed.
    if (kIsWeb) {
      if (!BrowserNotification.isSupported) return;
      if (BrowserNotification.permissionStatus != 'granted') return;
    }

    final token = await AuthService.getToken();
    if (token == null) return;

    try {
      final resp = await http
          .get(
            Uri.parse('${AuthService.baseUrl}/notifications/pending'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return;

      final notifications = jsonDecode(resp.body) as List<dynamic>;
      for (final n in notifications) {
        final id    = n['id'] as int?;
        final title = n['title'] as String? ?? 'LockedIn';
        final msg   = n['message'] as String? ?? '';

        await _showNotification(id ?? 0, title, msg);
        if (id != null) _acknowledge(id, token);
      }
    } catch (e) {
      debugPrint('Notification poll error: $e');
    }
  }

  static Future<void> _showNotification(int id, String title, String body) async {
    if (kIsWeb) {
      BrowserNotification.show(title, body);
    } else if (_localNotifsReady) {
      await _localNotifs.show(
        id & 0x7FFFFFFF, // keep within Android int range
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    }
  }

  static Future<void> _acknowledge(int id, String token) async {
    try {
      await http
          .post(
            Uri.parse('${AuthService.baseUrl}/notifications/$id/acknowledge'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  /// Call on logout to stop polling and reset state.
  static void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _initialized = false;
    _pushSubscribed = false;
    _localNotifsReady = false;
  }
}
