import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/app_usage_stat_model.dart';
import '../models/current_app_model.dart';

class AndroidLockInHelper {
  static const _channel = MethodChannel('focuspro/lockin');
  static const _accessibilityChannel = MethodChannel('focuspro/accessibility');

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

  /// Returns today's app usage stats. Returns empty list on any error.
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

  // ── Accessibility Service ─────────────────────────────────────────────────

  /// Returns true if FocusProAccessibilityService is enabled in Android Settings.
  static Future<bool> hasAccessibilityPermission() async {
    if (!_isAndroid) return false;
    try {
      final result =
          await _accessibilityChannel.invokeMethod<bool>('hasAccessibilityPermission');
      return result ?? false;
    } catch (e) {
      debugPrint('hasAccessibilityPermission error: $e');
      return false;
    }
  }

  /// Opens Android Accessibility Settings so the user can enable the service.
  static Future<void> requestAccessibilityPermission() async {
    if (!_isAndroid) return;
    try {
      await _accessibilityChannel.invokeMethod('requestAccessibilityPermission');
    } catch (e) {
      debugPrint('requestAccessibilityPermission error: $e');
    }
  }

  /// Drains the Kotlin event buffer and returns all captured screen-switch
  /// events since the last drain. Returns an empty list if nothing is buffered.
  static Future<List<Map<String, dynamic>>> drainEvents() async {
    if (!_isAndroid) return [];
    try {
      final result =
          await _accessibilityChannel.invokeMethod<String>('drainEvents');
      if (result == null || result == '[]') return [];
      final list = jsonDecode(result) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('drainEvents error: $e');
      return [];
    }
  }

  /// Returns the app the user is currently looking at, or null if the
  /// accessibility service is not running / nothing detected yet.
  static Future<CurrentAppModel?> getCurrentApp() async {
    if (!_isAndroid) return null;
    try {
      final result =
          await _accessibilityChannel.invokeMethod<String>('getCurrentApp');
      if (result == null) return null;
      final map = jsonDecode(result) as Map<String, dynamic>;
      return CurrentAppModel.fromJson(map);
    } catch (e) {
      debugPrint('getCurrentApp error: $e');
      return null;
    }
  }

  static bool get _isAndroid =>
      defaultTargetPlatform == TargetPlatform.android && !kIsWeb;
}
