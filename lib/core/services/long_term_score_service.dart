import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Fetches the long-term EMA focus score from the backend.
///
/// The EMA is calculated entirely server-side using all past daily_score
/// records  no SharedPreferences or on-device computation required.
///
/// Public API is identical to the old local implementation so all callers
/// (UserProvider) work without any changes.
class LongTermScoreService {
  // In-memory cache so getScore() and getWeekTrend() share a single network
  // round-trip per call to getScore().
  static double? _cachedScore;
  static double? _cachedWeekTrend;

  static Future<void> _refresh() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return;
      final resp = await http
          .get(
            Uri.parse('${AuthService.baseUrl}/score/longterm'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final score = (body['score'] as num?)?.toDouble() ?? 0.0;
        _cachedScore     = score > 0 ? score : null;
        _cachedWeekTrend = (body['weekTrend'] as num?)?.toDouble();
      }
    } catch (_) {
      // Network error  keep previously cached values
    }
  }

  /// Returns the current long-term EMA score (0–100).
  /// Returns null if the user hasn't completed the diagnostic yet.
  static Future<double?> getScore() async {
    await _refresh();
    return _cachedScore;
  }

  /// Returns the 7-day trend.  Positive = improving, negative = declining.
  /// Must be called after [getScore()]  shares the same cached fetch.
  static Future<double?> getWeekTrend() async {
    return _cachedWeekTrend;
  }

  /// Called after the diagnostic completes.
  /// Seeding now happens automatically on the backend when the diagnostic is
  /// submitted, so this just refreshes the locally cached values.
  static Future<void> seedFromDiagnostic(double diagnosticScore) async {
    await _refresh();
  }

  /// Triggers the backend EMA computation for unprocessed days and returns
  /// the refreshed score.  Returns null if the diagnostic hasn't been done yet.
  static Future<double?> processPendingDays() async {
    await _refresh();
    return _cachedScore;
  }
}
