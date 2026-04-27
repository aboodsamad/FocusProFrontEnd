import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/diagnostic_question.dart';
import '../../../core/services/auth_service.dart';

class DiagnosticService {
  // ── GET /diagnostic/questions ─────────────────────────────────────────────
  // Fetches the 15 questions from the backend.
  // Falls back to hardcoded list if API is down (keeps the UI usable).
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
          // Points are now computed server-side; pass 0 here so the model
          // builds correctly  the actual scoring happens in the backend.
          return DiagnosticQuestion.fromApi(
            e,
            pointsA: 0,
            pointsB: 0,
            pointsC: 0,
            pointsD: 0,
          );
        }).toList()
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

        return questions;
      }

      return _fallback();
    } catch (e) {
      return _fallback();
    }
  }

  // ── POST /diagnostic/submit ───────────────────────────────────────────────
  // Sends the user's answers to the backend.
  // The backend looks up question points from the DB and computes all scores.
  // Returns the confirmed focusScore, or null if the request failed.
  static Future<double?> submitSession(
    List<DiagnosticAnswer> answers,
    List<DiagnosticQuestion> questions,
    String token,
  ) async {
    final body = jsonEncode({
      'answers': answers
          .map((a) => {
                'questionId':     a.questionId,
                'selectedOption': a.selectedOption,
                'pointsEarned':   0, // ignored  backend computes from DB
              })
          .toList(),
    });

    final url = Uri.parse('${AuthService.baseUrl}/diagnostic/submit');
    try {
      final resp = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 12));

      // Backend returns: "Diagnostic complete! Focus score: 73.0/100 | Tier: ..."
      double? confirmedScore;
      if (resp.statusCode == 200) {
        final match =
            RegExp(r'Focus score:\s*([\d.]+)').firstMatch(resp.body);
        if (match != null) {
          confirmedScore = double.tryParse(match.group(1)!);
        }
      }

      if (confirmedScore != null) {
        // Cache locally so HomeScreen shows the score immediately on next open
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('focus_score', confirmedScore);
      }
      return confirmedScore;
    } catch (e) {
      return null;
    }
  }

  // ── Hardcoded fallback ────────────────────────────────────────────────────
  // Used when the API is unreachable OR when the user has no token yet
  // (unauthenticated diagnostic preview).
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
  //   Learning       → Need for Cognition Scale (NCS)
  //                    Cacioppo & Petty (1982), JPSP
  //                    Ebbinghaus (1885); Cepeda et al. (2006), Psych. Bulletin

  /// Public wrapper  lets the UI load questions even without a token.
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
      },
      {
        'id': 2,
        'question_text':
            'How often do you feel restless or uncomfortable when you cannot check your phone?',
        'option_a': 'Never  I feel no urge',
        'option_b': 'Occasionally',
        'option_c': 'Often',
        'option_d': 'Almost always  I feel anxious without it',
        'points_a': 4, 'points_b': 2, 'points_c': 1, 'points_d': 0,
        'dimension': 'screen_habits', 'display_order': 2,
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
      },
      {
        'id': 4,
        'question_text':
            'How often do you check your phone even without receiving a notification?',
        'option_a': 'Rarely  only when expecting something',
        'option_b': 'A few times a day',
        'option_c': 'Every hour or so',
        'option_d': 'Constantly  it\'s almost automatic',
        'points_a': 4, 'points_b': 3, 'points_c': 1, 'points_d': 0,
        'dimension': 'screen_habits', 'display_order': 4,
      },

      // ── ATTENTION (ASRS-v1.1 / CFQ) ─────────────────────────────────────
      {
        'id': 5,
        'question_text':
            'Reading comprehension task  read the passage and answer the questions that follow.',
        'option_a': 'Answered all questions correctly',
        'option_b': 'Answered most questions correctly',
        'option_c': 'Answered some questions correctly',
        'option_d': 'Struggled to recall the passage',
        'points_a': 5, 'points_b': 3, 'points_c': 1, 'points_d': 0,
        'dimension': 'attention', 'display_order': 5,
      },
      {
        'id': 6,
        'question_text':
            'Working memory task  read the passage and tap each time you re-read a sentence.',
        'option_a': 'Read it once with no re-reads',
        'option_b': 'Re-read 1–2 sentences',
        'option_c': 'Re-read 3–4 sentences',
        'option_d': 'Re-read 5 or more sentences',
        'points_a': 5, 'points_b': 3, 'points_c': 1, 'points_d': 0,
        'dimension': 'attention', 'display_order': 6,
      },
      {
        'id': 7,
        'question_text':
            'How often do you have difficulty sustaining attention during long or repetitive tasks?',
        'option_a': 'Rarely  I stay on task easily',
        'option_b': 'Sometimes  I drift but recover',
        'option_c': 'Often  it disrupts my work',
        'option_d': 'Almost always  I can rarely stay on task',
        'points_a': 5, 'points_b': 3, 'points_c': 1, 'points_d': 0,
        'dimension': 'attention', 'display_order': 7,
      },
      {
        'id': 8,
        'question_text':
            'How often do you find your mind wandering when you are trying to concentrate on something?',
        'option_a': 'Rarely  I can redirect focus easily',
        'option_b': 'Sometimes  requires some effort',
        'option_c': 'Often  it disrupts my concentration',
        'option_d': 'Almost always  I struggle to stay present',
        'points_a': 5, 'points_b': 3, 'points_c': 1, 'points_d': 0,
        'dimension': 'attention', 'display_order': 8,
      },
      {
        'id': 9,
        'question_text':
            'After a period of scrolling or switching between apps, how hard is it to return to focused work?',
        'option_a': 'Easy  I refocus almost immediately',
        'option_b': 'A few minutes to settle back in',
        'option_c': '15–30 minutes before I feel focused again',
        'option_d': 'I struggle to regain focus for an extended period',
        'points_a': 5, 'points_b': 3, 'points_c': 1, 'points_d': 0,
        'dimension': 'attention', 'display_order': 9,
      },

      // ── LIFESTYLE (PSQI / WHO Guidelines) ───────────────────────────────
      {
        'id': 10,
        'question_text':
            'How would you rate the quality of your sleep on most nights?',
        'option_a': 'Very good  I wake up feeling refreshed',
        'option_b': 'Fairly good  mostly rested',
        'option_c': 'Fairly poor  I often feel tired during the day',
        'option_d': 'Very poor  I rarely feel rested',
        'points_a': 3, 'points_b': 2, 'points_c': 1, 'points_d': 0,
        'dimension': 'lifestyle', 'display_order': 10,
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
      },
      {
        'id': 12,
        'question_text':
            'How consistent is your daily schedule (wake time, meals, work hours)?',
        'option_a': 'Very consistent  I follow a structured daily routine',
        'option_b': 'Mostly consistent with occasional variation',
        'option_c': 'Quite inconsistent  my schedule varies a lot',
        'option_d': 'No real routine  each day is unpredictable',
        'points_a': 3, 'points_b': 2, 'points_c': 1, 'points_d': 0,
        'dimension': 'lifestyle', 'display_order': 12,
      },

      // ── LEARNING (NCS / Ebbinghaus / Flow) ──────────────────────────────
      {
        'id': 13,
        'question_text':
            'When you encounter a mentally challenging problem, what is your first reaction?',
        'option_a': 'I engage with it  I enjoy the mental effort',
        'option_b': 'I work through it when I need to',
        'option_c': 'I prefer to find an easier approach',
        'option_d': 'I avoid it and look for someone else to solve it',
        'points_a': 3, 'points_b': 2, 'points_c': 1, 'points_d': 0,
        'dimension': 'learning', 'display_order': 13,
      },
      {
        'id': 14,
        'question_text':
            'How well do you typically remember something new you learned a few days later?',
        'option_a': 'Very well  I retain most details',
        'option_b': 'Fairly well  I remember the key points',
        'option_c': 'Poorly  I forget most of it quickly',
        'option_d': 'Barely at all  it fades within hours',
        'points_a': 3, 'points_b': 2, 'points_c': 1, 'points_d': 0,
        'dimension': 'learning', 'display_order': 14,
      },
      {
        'id': 15,
        'question_text':
            'How comfortable are you spending 60+ minutes on a single task without switching?',
        'option_a': 'Very comfortable  I prefer long deep work sessions',
        'option_b': 'Comfortable  I can do it when needed',
        'option_c': 'Uncomfortable  I feel the urge to switch after a short time',
        'option_d': 'Very difficult  I regularly break off to do other things',
        'points_a': 3, 'points_b': 2, 'points_c': 1, 'points_d': 0,
        'dimension': 'learning', 'display_order': 15,
      },
    ];
    return raw.map((e) => DiagnosticQuestion.fromFallback(e)).toList();
  }
}
