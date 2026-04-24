import 'package:flutter/foundation.dart';
import '../services/daily_score_service.dart';

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

  Future<void> init() async {
    _todayScore = await DailyScoreService.getTodayScore();
    _weeklyScores = await DailyScoreService.getWeeklyScores();
    notifyListeners();
  }

  Future<void> addPoints(double points) async {
    if (points <= 0) return;
    await DailyScoreService.addPoints(points);
    _todayScore += points;
    _weeklyScores = await DailyScoreService.getWeeklyScores();
    notifyListeners();
  }
}
