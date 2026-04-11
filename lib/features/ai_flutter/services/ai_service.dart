import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/services/auth_service.dart';
import '../models/ai_question_model.dart';

class AiService {
  static String get _base => AuthService.baseUrl;

  // ── Snippet comprehension ─────────────────────────────────────────────────

  static Future<List<AiQuestionModel>> getSnippetQuestions(int snippetId, String token) async {
    try {
      final resp = await http
          .get(
            Uri.parse('$_base/ai/snippet/$snippetId/questions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode == 200) {
        final List<dynamic> data = jsonDecode(resp.body);
        return data
            .map((e) => AiQuestionModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      print('AiService.getSnippetQuestions: status ${resp.statusCode} — ${resp.body}');
      return [];
    } catch (e) {
      print('AiService.getSnippetQuestions error: $e');
      return [];
    }
  }

  static Future<SnippetCheckResult?> submitSnippetAnswers(
      int snippetId, Map<int, String> answers, String token) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$_base/ai/snippet/$snippetId/submit'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'answers': answers.map((k, v) => MapEntry(k.toString(), v))}),
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        return SnippetCheckResult.fromJson(
            jsonDecode(resp.body) as Map<String, dynamic>);
      }
      print('AiService.submitSnippetAnswers: status ${resp.statusCode} — ${resp.body}');
      return null;
    } catch (e) {
      print('AiService.submitSnippetAnswers error: $e');
      return null;
    }
  }

  // ── Retention test ────────────────────────────────────────────────────────

  static Future<List<AiQuestionModel>> generateRetentionTest(String token) async {
    try {
      final resp = await http
          .get(
            Uri.parse('$_base/ai/retention/generate'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 25));

      if (resp.statusCode == 200) {
        final List<dynamic> data = jsonDecode(resp.body);
        return data
            .map((e) => AiQuestionModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      print('AiService.generateRetentionTest: status ${resp.statusCode} — ${resp.body}');
      return [];
    } catch (e) {
      print('AiService.generateRetentionTest error: $e');
      return [];
    }
  }

  static Future<RetentionTestResult?> submitRetentionTest(
      Map<int, String> answers, String token) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$_base/ai/retention/submit'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'answers': answers.map((k, v) => MapEntry(k.toString(), v))}),
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        return RetentionTestResult.fromJson(
            jsonDecode(resp.body) as Map<String, dynamic>);
      }
      print('AiService.submitRetentionTest: status ${resp.statusCode} — ${resp.body}');
      return null;
    } catch (e) {
      print('AiService.submitRetentionTest error: $e');
      return null;
    }
  }
}