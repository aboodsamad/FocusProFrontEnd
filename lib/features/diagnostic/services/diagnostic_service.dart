import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/diagnostic_question.dart';
import '../../../core/services/auth_service.dart';

class DiagnosticService {
  // Max raw scores per dimension — used to compute the final focusScore
  static const double _maxScreen    = 16.0; // Q1–Q4   (4+4+4+4)
  static const double _maxAttention = 25.0; // Q5–Q9   (5+5+5+5+5)
  static const double _maxLifestyle =  9.0; // Q10–Q12 (3+3+3)
  static const double _maxLearning  =  9.0; // Q13–Q15 (3+3+3)
  static const double _maxTotal     = 59.0;

  // ── Points per question by display_order ─────────────────────────────────
  // The backend DiagnosticQuestionDTO does NOT return points_a/b/c/d.
  // These are stored in the DB but not exposed by the DTO.
  // We match by displayOrder (1–15) to inject the correct points.
  // This is safe because the DB was seeded with these exact questions in order.
  static const Map<int, List<int>> _pointsByOrder = {
    1:  [4, 2, 1, 0],
    2:  [4, 2, 1, 0],
    3:  [4, 3, 1, 0],
    4:  [4, 3, 1, 0],
    5:  [5, 3, 1, 0],
    6:  [5, 3, 1, 0],
    7:  [5, 3, 1, 0],
    8:  [5, 3, 1, 0],
    9:  [5, 3, 1, 0],
    10: [3, 2, 1, 0],
    11: [3, 2, 1, 0],
    12: [3, 2, 1, 0],
    13: [3, 2, 1, 0],
    14: [3, 2, 1, 0],
    15: [3, 2, 1, 0],
  };

  // ── GET /diagnostic/questions ─────────────────────────────────────────────
  // Fetches the 15 questions from the DB via the backend.
  // Falls back to hardcoded if API is down (so UI never breaks).
  static Future<List<DiagnosticQuestion>> getQuestions(String token) async {
    final url = Uri.parse('${AuthService.baseUrl}/diagnostic/questions');
    try {
      final resp = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final List<dynamic> raw = jsonDecode(resp.body);
        final questions = raw.map((e) {
          final order  = (e['displayOrder'] as num?)?.toInt() ?? 0;
          final pts    = _pointsByOrder[order] ?? [3, 2, 1, 0];
          return DiagnosticQuestion.fromApi(
            e,
            pointsA: pts[0],
            pointsB: pts[1],
            pointsC: pts[2],
            pointsD: pts[3],
          );
        }).toList()
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

        print('DiagnosticService: loaded ${questions.length} questions from API');
        return questions;
      }

      print('DiagnosticService.getQuestions: ${resp.statusCode} — using fallback');
      return _fallback();
    } catch (e) {
      print('DiagnosticService.getQuestions error: $e — using fallback');
      return _fallback();
    }
  }

  // ── POST /diagnostic/submit ───────────────────────────────────────────────
  // Computes all scores from the answers, sends full DiagnosticSubmitRequest.
  // Also saves focusScore to SharedPreferences so HomeScreen shows it immediately.
  //
  // Request body matches Java DiagnosticSubmitRequest exactly:
  // {
  //   "answers":        [{ "questionId", "selectedOption", "pointsEarned" }, ...],
  //   "focusScore":     73.0,
  //   "rawTotal":       44.0,
  //   "screenScore":    87.5,
  //   "attentionScore": 68.0,
  //   "lifestyleScore": 77.7,
  //   "learningScore":  66.6
  // }
  static Future<double?> submitSession(
    List<DiagnosticAnswer> answers,
    List<DiagnosticQuestion> questions,
    String token,
  ) async {
    // Map questionId → dimension
    final dimMap = {for (final q in questions) q.id: q.dimension};

    double screenRaw = 0, attentionRaw = 0, lifestyleRaw = 0, learningRaw = 0;
    for (final a in answers) {
      switch (dimMap[a.questionId]) {
        case DiagnosticDimension.screenHabits:
          screenRaw += a.pointsEarned;
          break;
        case DiagnosticDimension.attention:
          attentionRaw += a.pointsEarned;
          break;
        case DiagnosticDimension.lifestyle:
          lifestyleRaw += a.pointsEarned;
          break;
        case DiagnosticDimension.learning:
          learningRaw += a.pointsEarned;
          break;
        case null:
          break;
      }
    }

    final rawTotal    = screenRaw + attentionRaw + lifestyleRaw + learningRaw;
    // Formula: 40 + round((rawTotal / 59) × 60)  →  range 40–100, average ≈ 70
    final focusScore  = (40 + (rawTotal / _maxTotal) * 60).roundToDouble();

    final body = jsonEncode({
      'answers':        answers.map((a) => a.toJson()).toList(),
      'focusScore':     focusScore,
      'rawTotal':       rawTotal,
      'screenScore':    (screenRaw    / _maxScreen)    * 100,
      'attentionScore': (attentionRaw / _maxAttention) * 100,
      'lifestyleScore': (lifestyleRaw / _maxLifestyle) * 100,
      'learningScore':  (learningRaw  / _maxLearning)  * 100,
    });

    print('DiagnosticService.submitSession — body: $body');

    final url = Uri.parse('${AuthService.baseUrl}/diagnostic/submit');
    try {
      final resp = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      ).timeout(const Duration(seconds: 12));

      print('DiagnosticService.submitSession response: ${resp.statusCode} ${resp.body}');

      // Parse the score the backend confirmed (it may differ slightly due to
      // its own rounding). Fall back to our computed value if parsing fails.
      double confirmedScore = focusScore;
      if (resp.statusCode == 200) {
        final match = RegExp(r'Focus score:\s*([\d.]+)').firstMatch(resp.body);
        if (match != null) {
          confirmedScore = double.tryParse(match.group(1)!) ?? focusScore;
        }
      } else {
        print('Submit returned ${resp.statusCode} — using locally computed score');
      }

      // Save to SharedPreferences immediately so HomeScreen reads the real value
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('focus_score', confirmedScore);
      print('DiagnosticService: saved focus_score = $confirmedScore to prefs');

      return confirmedScore;
    } catch (e) {
      print('DiagnosticService.submitSession error: $e');
      // Still save locally so the user sees a score even if network failed
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('focus_score', focusScore);
      return focusScore;
    }
  }

  // ── Hardcoded fallback (used if API is down) ──────────────────────────────
  static List<DiagnosticQuestion> _fallback() {
    final raw = [
      {'id':1,'question_text':'How many hours do you spend on social media daily?','option_a':'Less than 1 hour','option_b':'1–3 hours','option_c':'3–5 hours','option_d':'More than 5 hours','points_a':4,'points_b':2,'points_c':1,'points_d':0,'dimension':'screen_habits','display_order':1},
      {'id':2,'question_text':'How often do you pick up your phone without a specific reason?','option_a':'Rarely / Never','option_b':'A few times a day','option_c':'Every hour','option_d':'Every few minutes','points_a':4,'points_b':2,'points_c':1,'points_d':0,'dimension':'screen_habits','display_order':2},
      {'id':3,'question_text':'When you sit down to do something important, how quickly do you reach for your phone?','option_a':'I don\'t, I stay focused','option_b':'After 30+ minutes','option_c':'Within 10–15 minutes','option_d':'Almost immediately','points_a':4,'points_b':3,'points_c':1,'points_d':0,'dimension':'screen_habits','display_order':3},
      {'id':4,'question_text':'Do you use your phone before sleeping?','option_a':'Never','option_b':'Occasionally','option_c':'Most nights','option_d':'Every night, for a long time','points_a':4,'points_b':3,'points_c':1,'points_d':0,'dimension':'screen_habits','display_order':4},
      {'id':5,'question_text':'How long can you focus on a single task before your mind wanders?','option_a':'More than 45 minutes','option_b':'20–45 minutes','option_c':'10–20 minutes','option_d':'Less than 10 minutes','points_a':5,'points_b':3,'points_c':1,'points_d':0,'dimension':'attention','display_order':5},
      {'id':6,'question_text':'When reading something, how often do you re-read the same line?','option_a':'Rarely','option_b':'Sometimes','option_c':'Often','option_d':'Almost always — I can\'t retain what I read','points_a':5,'points_b':3,'points_c':1,'points_d':0,'dimension':'attention','display_order':6},
      {'id':7,'question_text':'How do you usually handle a task that requires deep thinking?','option_a':'I sit and work through it fully','option_b':'I work through it but take small breaks','option_c':'I struggle and often switch to something easier','option_d':'I avoid it or postpone it','points_a':5,'points_b':3,'points_c':1,'points_d':0,'dimension':'attention','display_order':7},
      {'id':8,'question_text':'Do you find yourself thinking about other things while someone is talking to you?','option_a':'Rarely','option_b':'Sometimes','option_c':'Often','option_d':'Almost always','points_a':5,'points_b':3,'points_c':1,'points_d':0,'dimension':'attention','display_order':8},
      {'id':9,'question_text':'After finishing a session of scrolling, how do you feel?','option_a':'I rarely scroll mindlessly','option_b':'Fine, it was a short break','option_c':'A bit drained or empty','option_d':'Very drained, like I wasted time','points_a':5,'points_b':3,'points_c':1,'points_d':0,'dimension':'attention','display_order':9},
      {'id':10,'question_text':'How many hours of sleep do you get on average?','option_a':'7–9 hours','option_b':'6–7 hours','option_c':'5–6 hours','option_d':'Less than 5 hours','points_a':3,'points_b':2,'points_c':1,'points_d':0,'dimension':'lifestyle','display_order':10},
      {'id':11,'question_text':'How often do you exercise or do physical activity?','option_a':'Daily or almost daily','option_b':'3–4 times a week','option_c':'Once a week','option_d':'Rarely or never','points_a':3,'points_b':2,'points_c':1,'points_d':0,'dimension':'lifestyle','display_order':11},
      {'id':12,'question_text':'How would you describe your daily routine?','option_a':'Very structured and consistent','option_b':'Mostly structured','option_c':'Somewhat chaotic','option_d':'No real routine','points_a':3,'points_b':2,'points_c':1,'points_d':0,'dimension':'lifestyle','display_order':12},
      {'id':13,'question_text':'How often do you read books, articles, or educational content?','option_a':'Daily','option_b':'A few times a week','option_c':'Rarely','option_d':'Never','points_a':3,'points_b':2,'points_c':1,'points_d':0,'dimension':'learning','display_order':13},
      {'id':14,'question_text':'When you learn something new, how well do you retain it?','option_a':'Very well, I remember most of it','option_b':'Fairly well','option_c':'I forget quickly','option_d':'I barely retain anything','points_a':3,'points_b':2,'points_c':1,'points_d':0,'dimension':'learning','display_order':14},
      {'id':15,'question_text':'How do you feel about tasks that take long periods of focused effort?','option_a':'I enjoy them','option_b':'I tolerate them fine','option_c':'I find them very uncomfortable','option_d':'I actively avoid them','points_a':3,'points_b':2,'points_c':1,'points_d':0,'dimension':'learning','display_order':15},
    ];
    return raw.map((e) => DiagnosticQuestion.fromFallback(e)).toList();
  }
}
