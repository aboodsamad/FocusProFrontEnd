import 'package:flutter/foundation.dart';
import '../services/daily_score_service.dart';
import '../services/auth_service.dart';

export '../services/daily_score_service.dart' show DailyScoreEntry;

class DailyScoreProvider extends ChangeNotifier {
  double _todayScore = 0.0;
  List<DailyScoreEntry> _weeklyScores = List.generate(
    7,
    (i) => DailyScoreEntry(
      date: DateTime.now().subtract(Duration(days: 6 - i)),
      score: 0.0,
    ),
  );

  double get todayScore => _todayScore;
  List<DailyScoreEntry> get weeklyScores => _weeklyScores;

  /// Called on app start. Loads from local storage immediately, then tries to
  /// reconcile with the backend so any cross-device or missed-sync data is merged.
  Future<void> init() async {
    // 1. Show local data immediately so the UI is not blank
    _todayScore = await DailyScoreService.getTodayScore();
    _weeklyScores = await DailyScoreService.getWeeklyScores();
    notifyListeners();

    // 2. Try syncing from backend in the background
    final token = await AuthService.getToken();
    if (token != null) {
      _todayScore = await DailyScoreService.syncTodayFromBackend(token);
      _weeklyScores = await DailyScoreService.syncWeeklyFromBackend(token);
      notifyListeners();
    }
  }

  /// Clears in-memory state on logout so stale data isn't visible while
  /// the next user's backend sync is loading.
  void reset() {
    _todayScore = 0.0;
    _weeklyScores = List.generate(
      7,
      (i) => DailyScoreEntry(
        date: DateTime.now().subtract(Duration(days: 6 - i)),
        score: 0.0,
      ),
    );
    notifyListeners();
  }

  /// Adds points both locally and to the backend.
  /// Local is written first so the UI updates instantly even if the network
  /// call is slow or fails.
  Future<void> addPoints(double points) async {
    if (points <= 0) return;

    // 1. Save locally -- instant, always succeeds
    await DailyScoreService.addPoints(points);
    _todayScore += points;
    _weeklyScores = await DailyScoreService.getWeeklyScores();
    notifyListeners();

    // 2. Sync to backend (fire-and-forget -- UI is already updated)
    final token = await AuthService.getToken();
    if (token != null) {
      await DailyScoreService.addPointsToBackend(points, token);
    }
  }
}
