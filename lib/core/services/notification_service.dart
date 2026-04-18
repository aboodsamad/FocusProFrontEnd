import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'browser_notification.dart';

/// Handles smart notifications for FocusPro.
///
/// Priority order:
/// 1. VAPID Web Push — works even when the browser tab is closed (if PWA installed)
/// 2. Polling fallback — works when the tab is open (no extra setup needed)
class NotificationService {
  static Timer? _pollTimer;
  static bool _initialized = false;
  static bool _pushSubscribed = false;

  /// Call once after login / on app start when already logged in.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Ask for browser notification permission
    await BrowserNotification.requestPermission();

    if (BrowserNotification.permissionStatus != 'granted') {
      debugPrint('Notification permission not granted — skipping push setup.');
      return;
    }

    // 2. Try to set up VAPID Web Push (background notifications)
    await _setupWebPush();

    // 3. Start polling as fallback (handles browsers/scenarios where push SW isn't active).
    // Also handles retry of push setup if the SW wasn't ready on first attempt.
    _startPolling();
  }

  static Future<void> _setupWebPush() async {
    final token = await AuthService.getToken();
    if (token == null) return;

    try {
      // Fetch VAPID public key from backend
      final keyResp = await http.get(
        Uri.parse('${AuthService.baseUrl}/notifications/vapid-public-key'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (keyResp.statusCode != 200) return;
      final vapidKey = (jsonDecode(keyResp.body) as Map<String, dynamic>)['key'] as String? ?? '';
      if (vapidKey.isEmpty) {
        debugPrint('VAPID key not configured on backend — using polling only.');
        return;
      }

      // Subscribe the browser to Web Push using the service worker
      final subscription = await BrowserNotification.subscribeToWebPush(vapidKey);
      if (subscription == null) {
        debugPrint('Web push subscription failed — using polling only.');
        return;
      }

      // Send subscription to backend
      final subResp = await http.post(
        Uri.parse('${AuthService.baseUrl}/notifications/web-push-subscribe'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(subscription),
      ).timeout(const Duration(seconds: 10));

      if (subResp.statusCode == 200) {
        _pushSubscribed = true;
        debugPrint('Web push subscription registered — background notifications active.');
      }
    } catch (e) {
      debugPrint('Web push setup error: $e');
    }
  }

  static void _startPolling() {
    _pollTimer?.cancel();
    _checkForNotifications(); // run immediately
    // Poll every 30 s so notifications appear faster when the app is open.
    // On odd ticks, also retry push setup in case the SW wasn't ready at login.
    int tick = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      tick++;
      if (!_pushSubscribed && tick % 4 == 0) {
        // Retry push setup every ~2 minutes until it succeeds
        await _setupWebPush();
      }
      _checkForNotifications();
    });
  }

  static Future<void> _checkForNotifications() async {
    if (!BrowserNotification.isSupported) return;
    if (BrowserNotification.permissionStatus != 'granted') return;

    final token = await AuthService.getToken();
    if (token == null) return;

    try {
      final resp = await http.get(
        Uri.parse('${AuthService.baseUrl}/notifications/pending'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) return;

      final notifications = jsonDecode(resp.body) as List<dynamic>;
      for (final n in notifications) {
        final id    = n['id'] as int?;
        final title = n['title'] as String? ?? 'FocusPro';
        final msg   = n['message'] as String? ?? '';

        BrowserNotification.show(title, msg);
        if (id != null) _acknowledge(id, token);
      }
    } catch (e) {
      debugPrint('Notification poll error: $e');
    }
  }

  static Future<void> _acknowledge(int id, String token) async {
    try {
      await http.post(
        Uri.parse('${AuthService.baseUrl}/notifications/$id/acknowledge'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  /// Call on logout to stop polling and reset state.
  static void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _initialized = false;
    _pushSubscribed = false;
  }
}
