import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'browser_notification.dart';

/// Smart notification service for FocusPro.
///
/// Strategy:
/// - Web: polls GET /notifications/pending every 60 s and shows browser notifications.
/// - Mobile (future): Firebase FCM handles delivery when Firebase is configured.
class NotificationService {
  static Timer? _pollTimer;
  static bool _initialized = false;

  /// Call once after the user logs in (or on app start if already logged in).
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Ask the browser for notification permission
    await BrowserNotification.requestPermission();

    // Start polling the backend every 60 seconds
    _startPolling();
  }

  static void _startPolling() {
    _pollTimer?.cancel();
    // Run once immediately, then every 60 seconds
    _checkForNotifications();
    _pollTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _checkForNotifications();
    });
  }

  static Future<void> _checkForNotifications() async {
    if (!BrowserNotification.isSupported) return;

    final token = await AuthService.getToken();
    if (token == null) return;

    try {
      final resp = await http
          .get(
            Uri.parse('${AuthService.baseUrl}/notifications/pending'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) return;

      final List<dynamic> notifications = jsonDecode(resp.body);
      for (final n in notifications) {
        final id = n['id'] as int?;
        final title = n['title'] as String? ?? 'FocusPro';
        final message = n['message'] as String? ?? '';

        // Show in browser
        BrowserNotification.show(title, message);

        // Tell backend it was shown so it won't repeat
        if (id != null) {
          _acknowledge(id, token);
        }
      }
    } catch (e) {
      debugPrint('NotificationService poll error: $e');
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

  /// Stop polling (call on logout).
  static void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _initialized = false;
  }
}
