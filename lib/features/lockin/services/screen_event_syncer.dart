import 'dart:async';
import 'package:flutter/foundation.dart';
import 'android_lockin_helper.dart';
import 'screen_event_service.dart';

/// Every 10 minutes, reads today's app usage totals from Android
/// UsageStatsManager and upserts them to the backend.
///
/// Uses PACKAGE_USAGE_STATS permission — no AccessibilityService needed.
/// One row per app per day on the server (no event spam).
class ScreenEventSyncer {
  ScreenEventSyncer._();
  static final instance = ScreenEventSyncer._();

  Timer? _timer;
  bool _running = false;

  static const _interval = Duration(minutes: 10);

  void start() {
    if (_running) return;
    _running = true;
    debugPrint('[ScreenEventSyncer] Started (10-min interval).');
    _sync();
    _timer = Timer.periodic(_interval, (_) => _sync());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
    debugPrint('[ScreenEventSyncer] Stopped.');
  }

  Future<void> _sync() async {
    try {
      final stats = await AndroidLockInHelper.getAppUsageToday();
      if (stats.isEmpty) return;
      await ScreenEventService.sendDailyUsage(stats);
    } catch (e) {
      debugPrint('[ScreenEventSyncer] Sync error: $e');
    }
  }
}
