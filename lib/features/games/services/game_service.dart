import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/services/auth_service.dart';

class GameResultResponse {
  final double focusScoreGained;
  final double newFocusScore;
  final String message;

  const GameResultResponse({
    required this.focusScoreGained,
    required this.newFocusScore,
    required this.message,
  });

  factory GameResultResponse.fromJson(Map<String, dynamic> json) {
    return GameResultResponse(
      focusScoreGained: (json['focusScoreGained'] as num?)?.toDouble() ?? 0.0,
      newFocusScore:    (json['newFocusScore']    as num?)?.toDouble() ?? 0.0,
      message:          (json['message'] as String?) ?? '',
    );
  }
}

class GameService {
  static Future<GameResultResponse?> submitResult({
    required String gameType,
    required int score,
    required int timePlayedSeconds,
    required bool completed,
    int levelReached = 0,
    int mistakes = 0,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) return null;

    final url = Uri.parse('${AuthService.baseUrl}/game/result');
    try {
      final resp = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'gameType':           gameType,
          'score':              score,
          'timePlayedSeconds':  timePlayedSeconds,
          'completed':          completed,
          'levelReached':       levelReached,
          'mistakes':           mistakes,
        }),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        return GameResultResponse.fromJson(
            jsonDecode(resp.body) as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('GameService.submitResult error: $e');
      return null;
    }
  }
}
