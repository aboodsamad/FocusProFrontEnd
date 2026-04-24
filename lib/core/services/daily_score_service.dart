import 'package:shared_preferences/shared_preferences.dart';

class DailyScoreEntry {
  final DateTime date;
  final double score;
  const DailyScoreEntry({required this.date, required this.score});
}

class DailyScoreService {
  static String _keyFor(DateTime date) =>
      'daily_score_${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static Future<double> getTodayScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyFor(DateTime.now())) ?? 0.0;
  }

  static Future<void> addPoints(double points) async {
    if (points <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final key = _keyFor(DateTime.now());
    final current = prefs.getDouble(key) ?? 0.0;
    await prefs.setDouble(key, current + points);
  }

  static Future<List<DailyScoreEntry>> getWeeklyScores() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    return List.generate(7, (i) {
      final date = now.subtract(Duration(days: 6 - i));
      final score = prefs.getDouble(_keyFor(date)) ?? 0.0;
      return DailyScoreEntry(date: date, score: score);
    });
  }
}
