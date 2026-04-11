import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/services/auth_service.dart';
import '../models/ai_question_model.dart';

class AiService {
  static String get _base => AuthService.baseUrl;

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Snippet comprehension ─────────────────────────────────────────────────

  /// GET /ai/snippet/{snippetId}/questions
  /// Fetches (or generates) 3 comprehension questions for the given snippet.
  static Future<List<AiQuestionModel>> getSnippetQuestions(int snippetId) async {
    try {
      final resp = await http
          .get(
            Uri.parse('$_base/ai/snippet/$snippetId/questions'),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 20)); // AI generation can take a few secs

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

  /// POST /ai/snippet/{snippetId}/submit
  /// Submits the user's answers and returns pass/fail + focus score result.
  /// [answers] = { questionId: chosenLetter }  e.g. { 1: 'A', 2: 'C', 3: 'B' }
  static Future<SnippetCheckResult?> submitSnippetAnswers(
      int snippetId, Map<int, String> answers) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$_base/ai/snippet/$snippetId/submit'),
            headers: await _headers(),
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

  /// GET /ai/retention/generate
  /// Generates a fresh retention test from past completed snippets.
  static Future<List<AiQuestionModel>> generateRetentionTest() async {
    try {
      final resp = await http
          .get(
            Uri.parse('$_base/ai/retention/generate'),
            headers: await _headers(),
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

  /// POST /ai/retention/submit
  /// Submits answers to the retention test and returns score delta.
  static Future<RetentionTestResult?> submitRetentionTest(
      Map<int, String> answers) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$_base/ai/retention/submit'),
            headers: await _headers(),
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
