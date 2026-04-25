import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class DailyScoreEntry {
  final DateTime date;
  final double score;
  const DailyScoreEntry({required this.date, required this.score});
}

class DailyScoreService {
  // ── Key helpers ──────────────────────────────────────────────────────────────
  static String _keyFor(DateTime date) =>
      'daily_score_${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  // ── Local storage ────────────────────────────────────────────────────────────
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

  // ── Backend sync ─────────────────────────────────────────────────────────────

  /// Fetches today's score from backend and updates local storage if backend
  /// value is higher. Returns the reconciled score (highest of local vs backend).
  static Future<double> syncTodayFromBackend(String token) async {
    try {
      final resp = await http
          .get(
            Uri.parse('${AuthService.baseUrl}/daily-score/today'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final backendTotal = (body['totalPoints'] as num?)?.toDouble() ?? 0.0;

        // Reconcile: take the higher of the two values and save it locally
        final prefs = await SharedPreferences.getInstance();
        final key = _keyFor(DateTime.now());
        final localTotal = prefs.getDouble(key) ?? 0.0;
        final merged = backendTotal > localTotal ? backendTotal : localTotal;
        if (merged != localTotal) {
          await prefs.setDouble(key, merged);
        }
        return merged;
      }
    } catch (e) {
      print('syncTodayFromBackend error: $e');
    }
    // Fall back to local value on any error
    return getTodayScore();
  }

  /// POSTs points to the backend. Fire-and-forget -- failures are silent.
  static Future<void> addPointsToBackend(double points, String token) async {
    if (points <= 0) return;
    try {
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
    } catch (e) {
      print('addPointsToBackend error: $e');
      // Local copy was already saved -- nothing to do here
    }
  }

  /// Fetches last 7 days from backend and merges with local (takes the max
  /// for each day so offline plays are not lost).
  static Future<List<DailyScoreEntry>> syncWeeklyFromBackend(String token) async {
    try {
      final resp = await http
          .get(
            Uri.parse('${AuthService.baseUrl}/daily-score/weekly'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List<dynamic>;
        final prefs = await SharedPreferences.getInstance();

        for (final entry in list) {
          final dateStr = entry['date'] as String?;
          final pts = (entry['totalPoints'] as num?)?.toDouble() ?? 0.0;
          if (dateStr == null) continue;

          final parts = dateStr.split('-');
          if (parts.length != 3) continue;
          final date = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
          final key = _keyFor(date);
          final localVal = prefs.getDouble(key) ?? 0.0;
          if (pts > localVal) {
            await prefs.setDouble(key, pts);
          }
        }
      }
    } catch (e) {
      print('syncWeeklyFromBackend error: $e');
    }

    // Always return from local (now merged)
    return getWeeklyScores();
  }
}
