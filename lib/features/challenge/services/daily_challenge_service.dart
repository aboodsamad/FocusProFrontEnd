import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/services/auth_service.dart';
import '../models/daily_challenge_model.dart';

class DailyChallengeService {
  static String get _base => AuthService.baseUrl;

  static Future<Map<String, String>> _authHeaders() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// GET /challenge/today
  /// Returns today's challenge. AI is called server-side if no challenge exists yet.
  static Future<DailyChallengeModel> getTodayChallenge() async {
    final resp = await http
        .get(
          Uri.parse('$_base/challenge/today'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 12));

    if (resp.statusCode == 200) {
      return DailyChallengeModel.fromJson(
          jsonDecode(resp.body) as Map<String, dynamic>);
    }
    throw Exception(
        'Failed to load daily challenge (${resp.statusCode}): ${resp.body}');
  }

  /// POST /challenge/{id}/complete
  static Future<DailyChallengeModel> completeChallenge(int id) async {
    final resp = await http
        .post(
          Uri.parse('$_base/challenge/$id/complete'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 12));

    if (resp.statusCode == 200) {
      return DailyChallengeModel.fromJson(
          jsonDecode(resp.body) as Map<String, dynamic>);
    }
    throw Exception(
        'Failed to complete challenge (${resp.statusCode}): ${resp.body}');
  }

  /// POST /challenge/hint
  static Future<DailyChallengeModel> submitHint(String hint) async {
    final resp = await http
        .post(
          Uri.parse('$_base/challenge/hint'),
          headers: await _authHeaders(),
          body: jsonEncode({'hint': hint}),
        )
        .timeout(const Duration(seconds: 12));

    if (resp.statusCode == 200) {
      return DailyChallengeModel.fromJson(
          jsonDecode(resp.body) as Map<String, dynamic>);
    }
    throw Exception(
        'Failed to submit hint (${resp.statusCode}): ${resp.body}');
  }
}
