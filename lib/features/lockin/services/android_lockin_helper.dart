import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/app_usage_stat_model.dart';

class AndroidLockInHelper {
  static const _channel = MethodChannel('LockedIn/lockin');

  // ── Usage access permission ───────────────────────────────────────────────

  /// Opens Android Usage Access settings screen.
  static Future<void> requestUsageStatsPermission() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('requestUsageStatsPermission');
    } catch (e) {
      debugPrint('requestUsageStatsPermission error: $e');
    }
  }

  /// Returns true if usage stats permission is granted.
  static Future<bool> hasUsageStatsPermission() async {
    if (!_isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('hasUsageStatsPermission');
      return result ?? false;
    } catch (e) {
      debugPrint('hasUsageStatsPermission error: $e');
      return false;
    }
  }

  // ── Daily usage totals (existing) ────────────────────────────────────────

  /// Returns today's app usage stats sorted by most used. Returns empty list on error.
  static Future<List<AppUsageStatModel>> getAppUsageToday() async {
    if (!_isAndroid) return [];
    try {
      final result = await _channel.invokeMethod<String>('getAppUsageToday');
      if (result == null) return [];
      final list = jsonDecode(result) as List<dynamic>;
      return list
          .map((e) => AppUsageStatModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('getAppUsageToday error: $e');
      return [];
    }
  }

  // ── queryEvents: real-time screen tracking ────────────────────────────────

  /// Returns the app the user is currently looking at by checking the most
  /// recent ACTIVITY_RESUMED event from the last 10 seconds.
  /// Returns null if nothing detected or permission not granted.
  static Future<Map<String, dynamic>?> getCurrentApp() async {
    if (!_isAndroid) return null;
    try {
      final result = await _channel.invokeMethod<String>('getCurrentApp');
      if (result == null) return null;
      return jsonDecode(result) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('getCurrentApp error: $e');
      return null;
    }
  }

  /// Returns all ACTIVITY_RESUMED events between [fromMs] and [toMs]
  /// as a list of maps ready to send to the backend.
  /// [fromMs] and [toMs] are milliseconds since epoch.
  static Future<List<Map<String, dynamic>>> getAppTimeline(
      int fromMs, int toMs) async {
    if (!_isAndroid) return [];
    try {
      final result = await _channel.invokeMethod<String>(
        'getAppTimeline',
        {'fromMs': fromMs, 'toMs': toMs},
      );
      if (result == null || result == '[]') return [];
      final list = jsonDecode(result) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('getAppTimeline error: $e');
      return [];
    }
  }

  // ── Lock-In session controls ──────────────────────────────────────────────

  /// Pins the app to the screen using Android startLockTask().
  static Future<void> startScreenPin() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('startScreenPin');
    } catch (e) {
      debugPrint('startScreenPin error: $e');
    }
  }

  /// Releases the screen pin via stopLockTask().
  static Future<void> stopScreenPin() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('stopScreenPin');
    } catch (e) {
      debugPrint('stopScreenPin error: $e');
    }
  }

  /// Schedules an alarm at the given time (HH:mm) tied to a scheduleId.
  static Future<void> scheduleAlarm(String timeHHmm, int scheduleId) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('scheduleAlarm', {
        'time': timeHHmm,
        'scheduleId': scheduleId,
      });
    } catch (e) {
      debugPrint('scheduleAlarm error: $e');
    }
  }

  /// Cancels the alarm for the given scheduleId.
  static Future<void> cancelAlarm(int scheduleId) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('cancelAlarm', {'scheduleId': scheduleId});
    } catch (e) {
      debugPrint('cancelAlarm error: $e');
    }
  }

  /// Acquires a wake lock to keep the screen on during a session.
  static Future<void> acquireWakeLock() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('acquireWakeLock');
    } catch (e) {
      debugPrint('acquireWakeLock error: $e');
    }
  }

  /// Releases the wake lock.
  static Future<void> releaseWakeLock() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('releaseWakeLock');
    } catch (e) {
      debugPrint('releaseWakeLock error: $e');
    }
  }

  static bool get _isAndroid =>
      defaultTargetPlatform == TargetPlatform.android && !kIsWeb;
}
