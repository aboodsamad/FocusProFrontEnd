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
  //
  // Scientific sources per dimension:
  //   Screen Habits  → Smartphone Addiction Scale-Short Version (SAS-SV)
  //                    Kwon et al. (2013), PLOS ONE
  //                    Bergen Social Media Addiction Scale (BSMAS)
  //                    Andreassen et al. (2016), Psychological Reports
  //   Attention      → Adult ADHD Self-Report Scale (ASRS-v1.1)
  //                    Kessler et al. (2005), Psychological Medicine (WHO)
  //                    Cognitive Failures Questionnaire (CFQ)
  //                    Broadbent et al. (1982), Journal of Experimental Psychology
  //   Lifestyle      → Pittsburgh Sleep Quality Index (PSQI)
  //                    Buysse et al. (1989), Psychiatry Research
  //                    WHO Physical Activity Guidelines for Adults (2020)
  //                    Circadian regularity & cognition: Saksvik-Lehouillier
  //                    et al. (2013), Sleep Medicine
  //   Learning       → Need for Cognition Scale (NCS)
  //                    Cacioppo & Petty (1982), JPSP
  //                    Forgetting Curve / Spaced Repetition
  //                    Ebbinghaus (1885); Cepeda et al. (2006), Psych. Bulletin
  //                    Flow & Deep Work: Csikszentmihalyi (1990); Newport (2016)
  //
  /// Public wrapper — lets the UI load questions even without a token.
  static List<DiagnosticQuestion> getFallbackQuestions() => _fallback();

  static List<DiagnosticQuestion> _fallback() {
    final raw = [
      // ── SCREEN HABITS (SAS-SV / BSMAS) ─────────────────────────────────
      {
        'id': 1,
        'question_text':
            'How often do you use your phone for longer than you originally intended?',
        'option_a': 'Rarely or never',
        'option_b': 'Sometimes',
        'option_c': 'Often',
        'option_d': 'Almost always',
        'points_a': 4, 'points_b': 2, 'points_c': 1, 'points_d': 0,
        'dimension': 'screen_habits', 'display_order': 1,
        // Source: SAS-SV Item 1 — Kwon et al., 2013
      },
      {
        'id': 2,
        'question_text':
            'How often do you feel restless or uncomfortable when you cannot check your phone?',
        'option_a': 'Never — I feel no urge',
        'option_b': 'Occasionally',
        'option_c': 'Often',
        'option_d': 'Almost always — I feel anxious without it',
        'points_a': 4, 'points_b': 2, 'points_c': 1, 'points_d': 0,
        'dimension': 'screen_habits', 'display_order': 2,
        // Source: BSMAS Withdrawal dimension — Andreassen et al., 2016
      },
      {
        'id': 3,
        'question_text':
            'How often do you use your phone within the hour before sleeping?',
        'option_a': 'Never',
        'option_b': 'Occasionally, less than 30 minutes',
        'option_c': 'Most nights, for 30+ minutes',
        'option_d': 'Every night, for over an hour',
        'points_a': 4, 'points_b': 3, 'points_c': 1, 'points_d': 0,
        'dimension': 'screen_habits', 'display_order': 3,
        // Source: Chang et al. (2015), PNAS — pre-sleep screen use & sleep quality
      },
      {
        'id': 4,
        'question_text':
            'How often do you check your phone even without receiving a notification?',
        'option_a': 'Rarely — only when expecting something',
        'option_b': 'A few times a day',
        'option_c': 'Every hour or so',
        'option_d': 'Constantly — it\'s almost automatic',
        'points_a': 4, 'points_b': 3, 'points_c': 1, 'points_d': 0,
        'dimension': 'screen_habits', 'display_order': 4,
        // Source: BSMAS Salience dimension; phantom vibration — Drouin et al., 2012
      },

      // ── ATTENTION (ASRS-v1.1 / CFQ) ─────────────────────────────────────
      {
        'id': 5,
        'question_text':
            'Reading comprehension task — read the passage and answer the questions that follow.',
        'option_a': 'Answered all questions correctly',
        'option_b': 'Answered most questions correctly',
        'option_c': 'Answered some questions correctly',
        'option_d': 'Struggled to recall the passage',
        'points_a': 5, 'points_b': 3, 'points_c': 1, 'points_d': 0,
        'dimension': 'attention', 'display_order': 5,
        // Source: Prose Recall paradigm — Daneman & Carpenter (1980);
        //         Mark et al. (2008), CHI — attention measurement via reading
      },
      {
        'id': 6,
        'question_text':
            'Working memory task — read the passage and tap each time you re-read a sentence.',
        'option_a': 'Read it once with no re-reads',
        'option_b': 'Re-read 1–2 sentences',
        'option_c': 'Re-read 3–4 sentences',
        'option_d': 'Re-read 5 or more sentences',
        'points_a': 5, 'points_b': 3, 'points_c': 1, 'points_d': 0,
        'dimension': 'attention', 'display_order': 6,
        // Source: Just & Carpenter (1992) — working memory in reading comprehension
      },
      {
        'id': 7,
        'question_text':
            'How often do you have difficulty sustaining attention during long or repetitive tasks?',
        'option_a': 'Rarely — I stay on task easily',
        'option_b': 'Sometimes — I drift but recover',
        'option_c': 'Often — it disrupts my work',
        'option_d': 'Almost always — I can rarely stay on task',
        'points_a': 5, 'points_b': 3, 'points_c': 1, 'points_d': 0,
        'dimension': 'attention', 'display_order': 7,
        // Source: ASRS-v1.1 Item 2 — Kessler et al. (2005)
      },
      {
        'id': 8,
        'question_text':
            'How often do you find your mind wandering when you are trying to concentrate on something?',
        'option_a': 'Rarely — I can redirect focus easily',
        'option_b': 'Sometimes — requires some effort',
        'option_c': 'Often — it disrupts my concentration',
        'option_d': 'Almost always — I struggle to stay present',
        'points_a': 5, 'points_b': 3, 'points_c': 1, 'points_d': 0,
        'dimension': 'attention', 'display_order': 8,
        // Source: CFQ Distractibility subscale — Broadbent et al. (1982)
      },
      {
        'id': 9,
        'question_text':
            'After a period of scrolling or switching between apps, how hard is it to return to focused work?',
        'option_a': 'Easy — I refocus almost immediately',
        'option_b': 'A few minutes to settle back in',
        'option_c': '15–30 minutes before I feel focused again',
        'option_d': 'I struggle to regain focus for an extended period',
        'points_a': 5, 'points_b': 3, 'points_c': 1, 'points_d': 0,
        'dimension': 'attention', 'display_order': 9,
        // Source: Attentional switching cost — Rogers & Monsell (1995);
        //         Gloria Mark: ~23 min to regain focus post-interruption
      },

      // ── LIFESTYLE (PSQI / WHO Guidelines) ───────────────────────────────
      {
        'id': 10,
        'question_text':
            'How would you rate the quality of your sleep on most nights?',
        'option_a': 'Very good — I wake up feeling refreshed',
        'option_b': 'Fairly good — mostly rested',
        'option_c': 'Fairly poor — I often feel tired during the day',
        'option_d': 'Very poor — I rarely feel rested',
        'points_a': 3, 'points_b': 2, 'points_c': 1, 'points_d': 0,
        'dimension': 'lifestyle', 'display_order': 10,
        // Source: PSQI Global Sleep Quality component — Buysse et al. (1989)
      },
      {
        'id': 11,
        'question_text':
            'How many days per week do you engage in at least 30 minutes of moderate physical activity?',
        'option_a': '5 or more days',
        'option_b': '3 to 4 days',
        'option_c': '1 to 2 days',
        'option_d': 'Rarely or never',
        'points_a': 3, 'points_b': 2, 'points_c': 1, 'points_d': 0,
        'dimension': 'lifestyle', 'display_order': 11,
        // Source: WHO Physical Activity Guidelines for Adults (2020); IPAQ
      },
      {
        'id': 12,
        'question_text':
            'How consistent is your daily schedule (wake time, meals, work hours)?',
        'option_a': 'Very consistent — I follow a structured daily routine',
        'option_b': 'Mostly consistent with occasional variation',
        'option_c': 'Quite inconsistent — my schedule varies a lot',
        'option_d': 'No real routine — each day is unpredictable',
        'points_a': 3, 'points_b': 2, 'points_c': 1, 'points_d': 0,
        'dimension': 'lifestyle', 'display_order': 12,
        // Source: Circadian rhythm regularity & cognition
        //         Saksvik-Lehouillier et al. (2013), Sleep Medicine
      },

      // ── LEARNING (NCS / Ebbinghaus / Flow) ──────────────────────────────
      {
        'id': 13,
        'question_text':
            'When you encounter a mentally challenging problem, what is your first reaction?',
        'option_a': 'I engage with it — I enjoy the mental effort',
        'option_b': 'I work through it when I need to',
        'option_c': 'I prefer to find an easier approach',
        'option_d': 'I avoid it and look for someone else to solve it',
        'points_a': 3, 'points_b': 2, 'points_c': 1, 'points_d': 0,
        'dimension': 'learning', 'display_order': 13,
        // Source: Need for Cognition Scale (NCS) — Cacioppo & Petty (1982), JPSP
      },
      {
        'id': 14,
        'question_text':
            'How well do you typically remember something new you learned a few days later?',
        'option_a': 'Very well — I retain most details',
        'option_b': 'Fairly well — I remember the key points',
        'option_c': 'Poorly — I forget most of it quickly',
        'option_d': 'Barely at all — it fades within hours',
        'points_a': 3, 'points_b': 2, 'points_c': 1, 'points_d': 0,
        'dimension': 'learning', 'display_order': 14,
        // Source: Ebbinghaus Forgetting Curve (1885);
        //         Cepeda et al. (2006), Psychological Bulletin — spaced repetition
      },
      {
        'id': 15,
        'question_text':
            'How comfortable are you spending 60+ minutes on a single task without switching?',
        'option_a': 'Very comfortable — I prefer long deep work sessions',
        'option_b': 'Comfortable — I can do it when needed',
        'option_c': 'Uncomfortable — I feel the urge to switch after a short time',
        'option_d': 'Very difficult — I regularly break off to do other things',
        'points_a': 3, 'points_b': 2, 'points_c': 1, 'points_d': 0,
        'dimension': 'learning', 'display_order': 15,
        // Source: Flow theory — Csikszentmihalyi (1990);
        //         Deep Work concept — Newport (2016)
      },
    ];
    return raw.map((e) => DiagnosticQuestion.fromFallback(e)).toList();
  }
}
