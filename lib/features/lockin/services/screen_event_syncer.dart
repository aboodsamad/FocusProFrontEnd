import 'dart:async';
import 'package:flutter/foundation.dart';
import 'android_lockin_helper.dart';
import 'screen_event_service.dart';

/// Background syncer that drains the Kotlin event buffer every 30 seconds
/// and POSTs the events to the backend.
///
/// Usage — start once when the app is ready (e.g. after login):
///   ScreenEventSyncer.instance.start();
///
/// Stop when the user logs out:
///   ScreenEventSyncer.instance.stop();
class ScreenEventSyncer {
  ScreenEventSyncer._();
  static final instance = ScreenEventSyncer._();

  Timer? _timer;
  bool _running = false;

  static const _interval = Duration(seconds: 30);

  /// Starts the periodic sync. Safe to call multiple times — ignores if already running.
  void start() {
    if (_running) return;
    _running = true;
    debugPrint('[ScreenEventSyncer] Started.');
    // Run once immediately, then every 30s
    _sync();
    _timer = Timer.periodic(_interval, (_) => _sync());
  }

  /// Stops the syncer and cancels the timer.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
    debugPrint('[ScreenEventSyncer] Stopped.');
  }

  Future<void> _sync() async {
    try {
      final events = await AndroidLockInHelper.drainEvents();
      if (events.isEmpty) return;
      await ScreenEventService.sendBatch(events);
    } catch (e) {
      debugPrint('[ScreenEventSyncer] Error during sync: $e');
    }
  }
}
