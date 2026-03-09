import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/diagnostic_question.dart';
import '../../../core/services/auth_service.dart';

class DiagnosticService {
  // ── Fetch all 15 diagnostic questions ─────────────────────────────────────
  static Future<List<DiagnosticQuestion>> getQuestions(String token) async {
    final url = Uri.parse('${AuthService.baseUrl}/diagnostic/questions');
    try {
      final resp = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 8));

      if (resp.statusCode != 200) return _fallbackQuestions();

      final List<dynamic> raw = jsonDecode(resp.body);
      return raw.map((e) => DiagnosticQuestion.fromJson(e)).toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    } catch (e) {
      print('DiagnosticService.getQuestions error: $e');
      return _fallbackQuestions();
    }
  }

  // ── Submit all answers in one shot ────────────────────────────────────────
  // Backend receives answers, computes score, writes to diagnostic_session
  // and updates users.focusScore — all in one transaction.
  static Future<double?> submitSession(
    List<DiagnosticAnswer> answers,
    String token,
  ) async {
    final url = Uri.parse('${AuthService.baseUrl}/diagnostic/submit');
    try {
      final resp = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'answers': answers.map((a) => a.toJson()).toList(),
        }),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        return (body['focusScore'] as num?)?.toDouble();
      }
      return null;
    } catch (e) {
      print('DiagnosticService.submitSession error: $e');
      return null;
    }
  }

  // ── Fallback: hardcoded questions if API is down ───────────────────────────
  // Lets you test the UI without the backend running
  static List<DiagnosticQuestion> _fallbackQuestions() {
    final raw = [
      // screen_habits
      {'id':1,'question_text':'How many hours do you spend on social media daily?','option_a':'Less than 1 hour','option_b':'1–3 hours','option_c':'3–5 hours','option_d':'More than 5 hours','points_a':4,'points_b':2,'points_c':1,'points_d':0,'dimension':'screen_habits','display_order':1},
      {'id':2,'question_text':'How often do you pick up your phone without a specific reason?','option_a':'Rarely / Never','option_b':'A few times a day','option_c':'Every hour','option_d':'Every few minutes','points_a':4,'points_b':2,'points_c':1,'points_d':0,'dimension':'screen_habits','display_order':2},
      {'id':3,'question_text':'When you sit down to do something important, how quickly do you reach for your phone?','option_a':'I don\'t, I stay focused','option_b':'After 30+ minutes','option_c':'Within 10–15 minutes','option_d':'Almost immediately','points_a':4,'points_b':3,'points_c':1,'points_d':0,'dimension':'screen_habits','display_order':3},
      {'id':4,'question_text':'Do you use your phone before sleeping?','option_a':'Never','option_b':'Occasionally','option_c':'Most nights','option_d':'Every night, for a long time','points_a':4,'points_b':3,'points_c':1,'points_d':0,'dimension':'screen_habits','display_order':4},
      // attention
      {'id':5,'question_text':'How long can you focus on a single task before your mind wanders?','option_a':'More than 45 minutes','option_b':'20–45 minutes','option_c':'10–20 minutes','option_d':'Less than 10 minutes','points_a':5,'points_b':3,'points_c':1,'points_d':0,'dimension':'attention','display_order':5},
      {'id':6,'question_text':'When reading something, how often do you re-read the same line?','option_a':'Rarely','option_b':'Sometimes','option_c':'Often','option_d':'Almost always — I can\'t retain what I read','points_a':5,'points_b':3,'points_c':1,'points_d':0,'dimension':'attention','display_order':6},
      {'id':7,'question_text':'How do you usually handle a task that requires deep thinking?','option_a':'I sit and work through it fully','option_b':'I work through it but take small breaks','option_c':'I struggle and often switch to something easier','option_d':'I avoid it or postpone it','points_a':5,'points_b':3,'points_c':1,'points_d':0,'dimension':'attention','display_order':7},
      {'id':8,'question_text':'Do you find yourself thinking about other things while someone is talking to you?','option_a':'Rarely','option_b':'Sometimes','option_c':'Often','option_d':'Almost always','points_a':5,'points_b':3,'points_c':1,'points_d':0,'dimension':'attention','display_order':8},
      {'id':9,'question_text':'After finishing a session of scrolling, how do you feel?','option_a':'I rarely scroll mindlessly','option_b':'Fine, it was a short break','option_c':'A bit drained or empty','option_d':'Very drained, like I wasted time','points_a':5,'points_b':3,'points_c':1,'points_d':0,'dimension':'attention','display_order':9},
      // lifestyle
      {'id':10,'question_text':'How many hours of sleep do you get on average?','option_a':'7–9 hours','option_b':'6–7 hours','option_c':'5–6 hours','option_d':'Less than 5 hours','points_a':3,'points_b':2,'points_c':1,'points_d':0,'dimension':'lifestyle','display_order':10},
      {'id':11,'question_text':'How often do you exercise or do physical activity?','option_a':'Daily or almost daily','option_b':'3–4 times a week','option_c':'Once a week','option_d':'Rarely or never','points_a':3,'points_b':2,'points_c':1,'points_d':0,'dimension':'lifestyle','display_order':11},
      {'id':12,'question_text':'How would you describe your daily routine?','option_a':'Very structured and consistent','option_b':'Mostly structured','option_c':'Somewhat chaotic','option_d':'No real routine','points_a':3,'points_b':2,'points_c':1,'points_d':0,'dimension':'lifestyle','display_order':12},
      // learning
      {'id':13,'question_text':'How often do you read books, articles, or educational content?','option_a':'Daily','option_b':'A few times a week','option_c':'Rarely','option_d':'Never','points_a':3,'points_b':2,'points_c':1,'points_d':0,'dimension':'learning','display_order':13},
      {'id':14,'question_text':'When you learn something new, how well do you retain it?','option_a':'Very well, I remember most of it','option_b':'Fairly well','option_c':'I forget quickly','option_d':'I barely retain anything','points_a':3,'points_b':2,'points_c':1,'points_d':0,'dimension':'learning','display_order':14},
      {'id':15,'question_text':'How do you feel about tasks that take long periods of focused effort?','option_a':'I enjoy them','option_b':'I tolerate them fine','option_c':'I find them very uncomfortable','option_d':'I actively avoid them','points_a':3,'points_b':2,'points_c':1,'points_d':0,'dimension':'learning','display_order':15},
    ];
    return raw.map((e) => DiagnosticQuestion.fromJson(e)).toList();
  }
}
