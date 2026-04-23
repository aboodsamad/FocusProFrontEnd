import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/services/auth_service.dart';
import '../models/daily_game_models.dart';

class DailyGameService {
  static String get _base => AuthService.baseUrl;

  static Future<Map<String, String>> _authHeaders() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<DailyGameStatus> getTodayStatus() async {
    final resp = await http
        .get(Uri.parse('$_base/daily-game/today'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 10));

    if (resp.statusCode == 200) {
      return DailyGameStatus.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to load daily game status (${resp.statusCode})');
  }

  static Future<DailyGameStatus> submitScore({
    required int score,
    required int timePlayedSeconds,
    required bool completed,
    required int levelReached,
    required int mistakes,
  }) async {
    final resp = await http
        .post(
          Uri.parse('$_base/daily-game/submit'),
          headers: await _authHeaders(),
          body: jsonEncode({
            'score':             score,
            'timePlayedSeconds': timePlayedSeconds,
            'completed':         completed,
            'levelReached':      levelReached,
            'mistakes':          mistakes,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (resp.statusCode == 409) {
      throw Exception('Already played today');
    }
    if (resp.statusCode == 200) {
      return DailyGameStatus.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to submit daily score (${resp.statusCode})');
  }

  static Future<DailyGameLeaderboard> getLeaderboard() async {
    final resp = await http
        .get(Uri.parse('$_base/daily-game/leaderboard'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 10));

    if (resp.statusCode == 200) {
      return DailyGameLeaderboard.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to load leaderboard (${resp.statusCode})');
  }
}
