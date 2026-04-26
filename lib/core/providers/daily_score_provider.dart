import 'package:flutter/foundation.dart';
import '../services/daily_score_service.dart';

export '../services/daily_score_service.dart' show DailyScoreEntry;

/// Provides daily score data to the widget tree.
/// All persistence is server-side — no local SharedPreferences caching needed.
class DailyScoreProvider extends ChangeNotifier {
  double _todayScore = 0.0;
  List<DailyScoreEntry> _weeklyScores = List.generate(
    7,
    (i) => DailyScoreEntry(
      date:  DateTime.now().subtract(Duration(days: 6 - i)),
      score: 0.0,
    ),
  );

  double get todayScore   => _todayScore;
  List<DailyScoreEntry> get weeklyScores => _weeklyScores;

  /// Loads today's score and weekly history from the backend.
  /// Called once after login.
  Future<void> init() async {
    _todayScore   = await DailyScoreService.getTodayScore();
    _weeklyScores = await DailyScoreService.getWeeklyScores();
    notifyListeners();
  }

  /// Resets to zero on logout so stale data isn't shown on the next login.
  void reset() {
    _todayScore   = 0.0;
    _weeklyScores = List.generate(
      7,
      (i) => DailyScoreEntry(
        date:  DateTime.now().subtract(Duration(days: 6 - i)),
        score: 0.0,
      ),
    );
    notifyListeners();
  }

  /// Adds [points] to today's score.
  /// Updates the UI optimistically then syncs to backend and refreshes weekly.
  Future<void> addPoints(double points) async {
    if (points <= 0) return;
    // Optimistic: show the new total immediately
    _todayScore += points;
    notifyListeners();
    // Persist to backend
    await DailyScoreService.addPoints(points);
    // Refresh the weekly chart with confirmed backend totals
    _weeklyScores = await DailyScoreService.getWeeklyScores();
    notifyListeners();
  }
}
