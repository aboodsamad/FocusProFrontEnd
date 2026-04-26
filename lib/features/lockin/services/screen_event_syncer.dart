import 'dart:async';
import 'package:flutter/foundation.dart';
import 'android_lockin_helper.dart';
import 'screen_event_service.dart';

/// Polls queryEvents() every 30 seconds and sends any new app-switch
/// events to the backend.
///
/// Uses the PACKAGE_USAGE_STATS permission — no AccessibilityService needed.
///
/// Usage:
///   ScreenEventSyncer.instance.start();  // after login
///   ScreenEventSyncer.instance.stop();   // on logout
class ScreenEventSyncer {
  ScreenEventSyncer._();
  static final instance = ScreenEventSyncer._();

  Timer? _timer;
  bool _running = false;

  /// Tracks the last time we queried so we never send duplicates.
  int _lastSyncMs = DateTime.now().millisecondsSinceEpoch;

  static const _interval = Duration(seconds: 30);

  /// Starts the periodic sync. Safe to call multiple times.
  void start() {
    if (_running) return;
    _running = true;
    _lastSyncMs = DateTime.now().millisecondsSinceEpoch;
    debugPrint('[ScreenEventSyncer] Started.');
    // Run once immediately then every 30 seconds
    _sync();
    _timer = Timer.periodic(_interval, (_) => _sync());
  }

  /// Stops the syncer.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
    debugPrint('[ScreenEventSyncer] Stopped.');
  }

  Future<void> _sync() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Ask Android for every app-switch event since the last sync
      final events = await AndroidLockInHelper.getAppTimeline(_lastSyncMs, now);

      _lastSyncMs = now; // always advance, even if send fails

      if (events.isEmpty) return;
      await ScreenEventService.sendBatch(events);
    } catch (e) {
      debugPrint('[ScreenEventSyncer] Sync error: $e');
    }
  }
}
