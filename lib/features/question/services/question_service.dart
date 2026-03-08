import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/question.dart';
import '../../../core/services/auth_service.dart';

class QuestionService {
  // ── Fetch questions from API ──────────────────────────────
  static Future<List<Question>> getQuestions(String token) async {
    final url = Uri.parse('${AuthService.baseUrl}/question/test/baseline');
    print('GET $url');

    try {
      final resp = await http
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(Duration(seconds: 8));

      print('Response code: ${resp.statusCode}');

      if (resp.statusCode != 200) {
        print('Failed to load questions: ${resp.statusCode} ${resp.body}');
        return [];
      }

      final decoded = jsonDecode(resp.body.trim());

      List<dynamic> rawList;
      if (decoded is List) {
        rawList = decoded;
      } else if (decoded is Map && decoded['questions'] is List) {
        rawList = decoded['questions'];
      } else if (decoded is Map && decoded['data'] is List) {
        rawList = decoded['data'];
      } else {
        print('Unexpected questions format: $decoded');
        return [];
      }

      return rawList
          .map((e) {
            if (e is! Map) return null;
            final id = int.tryParse(e['id']?.toString() ?? '') ?? 0;
            final text = e['questionText']?.toString() ?? '';
            final options = [
              e['optionA']?.toString() ?? '',
              e['optionB']?.toString() ?? '',
              e['optionC']?.toString() ?? '',
              e['optionD']?.toString() ?? '',
            ];
            final correctLetter =
                (e['correctAnswer']?.toString() ?? '').toUpperCase();
            final correctIndex =
                {'A': 0, 'B': 1, 'C': 2, 'D': 3}[correctLetter] ?? 0;

            return Question(
              id: id,
              text: text,
              options: options,
              correctIndex: correctIndex,
            );
          })
          .whereType<Question>()
          .toList();
    } catch (e) {
      print('Error fetching questions: $e');
      return [];
    }
  }

  // ── Submit a single answer ────────────────────────────────
  static Future<bool?> submitAnswer(
    int questionId,
    int selectedIndex,
    String token,
  ) async {
    final letters = ['A', 'B', 'C', 'D'];
    final answerLetter = (selectedIndex >= 0 && selectedIndex < letters.length)
        ? letters[selectedIndex]
        : 'A';

    final url = Uri.parse(
      '${AuthService.baseUrl}/question/test-answer/$questionId?answer=$answerLetter',
    );
    print('Submitting answer to: $url');

    try {
      final resp = await http
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(Duration(seconds: 8));

      print('Answer response: ${resp.statusCode} ${resp.body}');

      if (resp.statusCode == 200) {
        final body = resp.body.trim().toLowerCase();
        return body == 'true' || body == '"true"' || body.contains('true');
      }
      return null;
    } catch (e) {
      print('Error submitting answer: $e');
      return null;
    }
  }

  // ── Submit final test score ───────────────────────────────
  static Future<void> submitTestScore(int score, String token) async {
    final url = Uri.parse(
      '${AuthService.baseUrl}/question/submit-test/baseline?score=$score',
    );
    try {
      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
    } catch (e) {
      print('Error submitting score: $e');
    }
  }
}
