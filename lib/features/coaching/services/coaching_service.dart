import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/services/auth_service.dart';
import '../models/coaching_message.dart';
import '../models/daily_goal_model.dart';

class CoachingResponse {
  final String reply;
  final int sessionId;
  final List<DailyGoalModel> updatedGoals;
  /// Full conversation history — only present in GET /coaching/session/today
  final List<CoachingMessage>? messages;

  const CoachingResponse({
    required this.reply,
    required this.sessionId,
    required this.updatedGoals,
    this.messages,
  });

  factory CoachingResponse.fromJson(Map<String, dynamic> json) {
    final goalsList = (json['updatedGoals'] as List<dynamic>? ?? [])
        .map((e) => DailyGoalModel.fromJson(e as Map<String, dynamic>))
        .toList();

    final rawMsgs = json['messages'] as List<dynamic>?;
    List<CoachingMessage>? parsedMsgs;
    if (rawMsgs != null) {
      parsedMsgs = rawMsgs.map((e) {
        final m = e as Map<String, dynamic>;
        final backendRole = m['role'] as String? ?? 'assistant';
        return CoachingMessage(
          role: backendRole == 'assistant' ? 'ai' : 'user',
          content: m['content'] as String? ?? '',
          timestamp: DateTime.now(),
        );
      }).toList();
    }

    return CoachingResponse(
      reply: json['reply'] as String? ?? '',
      sessionId: (json['sessionId'] as num?)?.toInt() ?? 0,
      updatedGoals: goalsList,
      messages: parsedMsgs,
    );
  }
}

class CoachingService {
  static String get _base => AuthService.baseUrl;

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  /// POST /coaching/goals — set morning goals
  static Future<CoachingResponse?> setDailyGoals(
      String token, List<String> goals) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$_base/coaching/goals'),
            headers: _headers(token),
            body: jsonEncode({'goals': goals}),
          )
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode == 200) {
        return CoachingResponse.fromJson(
            jsonDecode(resp.body) as Map<String, dynamic>);
      }
      debugPrint('CoachingService.setDailyGoals: status ${resp.statusCode} — ${resp.body}');
      return null;
    } catch (e) {
      debugPrint('CoachingService.setDailyGoals error: $e');
      return null;
    }
  }

  /// POST /coaching/session/{sessionId}/message
  static Future<CoachingResponse?> sendMessage(
      String token, int sessionId, String message) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$_base/coaching/session/$sessionId/message'),
            headers: _headers(token),
            body: jsonEncode({'message': message}),
          )
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode == 200) {
        return CoachingResponse.fromJson(
            jsonDecode(resp.body) as Map<String, dynamic>);
      }
      debugPrint('CoachingService.sendMessage: status ${resp.statusCode} — ${resp.body}');
      return null;
    } catch (e) {
      debugPrint('CoachingService.sendMessage error: $e');
      return null;
    }
  }

  /// POST /coaching/evening
  static Future<CoachingResponse?> startEvening(String token) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$_base/coaching/evening'),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode == 200) {
        return CoachingResponse.fromJson(
            jsonDecode(resp.body) as Map<String, dynamic>);
      }
      debugPrint('CoachingService.startEvening: status ${resp.statusCode} — ${resp.body}');
      return null;
    } catch (e) {
      debugPrint('CoachingService.startEvening error: $e');
      return null;
    }
  }

  /// GET /coaching/session/today — restore session after logout/login
  static Future<CoachingResponse?> getTodaySession(String token) async {
    try {
      final resp = await http
          .get(
            Uri.parse('$_base/coaching/session/today'),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        return CoachingResponse.fromJson(
            jsonDecode(resp.body) as Map<String, dynamic>);
      }
      return null; // 404 = no session today yet
    } catch (e) {
      debugPrint('CoachingService.getTodaySession error: $e');
      return null;
    }
  }

  /// GET /coaching/goals/today
  static Future<List<DailyGoalModel>> getTodayGoals(String token) async {
    try {
      final resp = await http
          .get(
            Uri.parse('$_base/coaching/goals/today'),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final List<dynamic> data = jsonDecode(resp.body);
        return data
            .map((e) => DailyGoalModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      debugPrint('CoachingService.getTodayGoals: status ${resp.statusCode}');
      return [];
    } catch (e) {
      debugPrint('CoachingService.getTodayGoals error: $e');
      return [];
    }
  }

  /// PATCH /coaching/goals/{goalId}/status
  static Future<DailyGoalModel?> updateGoalStatus(
      String token, int goalId, String status) async {
    try {
      final resp = await http
          .patch(
            Uri.parse('$_base/coaching/goals/$goalId/status'),
            headers: _headers(token),
            body: jsonEncode({'status': status}),
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        return DailyGoalModel.fromJson(
            jsonDecode(resp.body) as Map<String, dynamic>);
      }
      debugPrint('CoachingService.updateGoalStatus: status ${resp.statusCode}');
      return null;
    } catch (e) {
      debugPrint('CoachingService.updateGoalStatus error: $e');
      return null;
    }
  }
}
