import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class DailyScoreEntry {
  final DateTime date;
  final double score;
  const DailyScoreEntry({required this.date, required this.score});
}

/// Thin HTTP wrapper around the backend /daily-score endpoints.
/// All persistence is server-side — SharedPreferences no longer needed.
class DailyScoreService {
  // ── Read today's score ───────────────────────────────────────────────────────

  static Future<double> getTodayScore() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return 0.0;
      final resp = await http
          .get(
            Uri.parse('${AuthService.baseUrl}/daily-score/today'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        return (body['totalPoints'] as num?)?.toDouble() ?? 0.0;
      }
    } catch (_) {}
    return 0.0;
  }

  // ── Add points ───────────────────────────────────────────────────────────────

  static Future<void> addPoints(double points) async {
    if (points <= 0) return;
    try {
      final token = await AuthService.getToken();
      if (token == null) return;
      await http
          .post(
            Uri.parse('${AuthService.baseUrl}/daily-score/add'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'points': points}),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  // ── Weekly history ───────────────────────────────────────────────────────────

  static Future<List<DailyScoreEntry>> getWeeklyScores() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return _emptyWeek();
      final resp = await http
          .get(
            Uri.parse('${AuthService.baseUrl}/daily-score/weekly'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List<dynamic>;
        return list
            .map((e) => DailyScoreEntry(
                  date:  DateTime.parse(e['date'] as String),
                  score: (e['totalPoints'] as num?)?.toDouble() ?? 0.0,
                ))
            .toList();
      }
    } catch (_) {}
    return _emptyWeek();
  }

  static List<DailyScoreEntry> _emptyWeek() => List.generate(
        7,
        (i) => DailyScoreEntry(
          date:  DateTime.now().subtract(Duration(days: 6 - i)),
          score: 0.0,
        ),
      );
}
