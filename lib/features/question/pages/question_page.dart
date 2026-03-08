import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../models/question.dart';
import '../services/question_service.dart';
import '../widgets/question_progress_bar.dart';
import '../widgets/question_option_tile.dart';
import '../../home/pages/home_page.dart';

class QuestionPage extends StatefulWidget {
  const QuestionPage({super.key});

  @override
  State<QuestionPage> createState() => _QuestionPageState();
}

class _QuestionPageState extends State<QuestionPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int selectedoption = -1;
  int questionNumber = 0;
  int score          = 0;
  int seconds        = 10;

  Timer? _questionTimer;

  // Token is cached once on load — no SharedPreferences read on every button press
  String? _cachedToken;

  List<Question> questions = [];

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _controller.forward();
    _loadQuestions();
  }

  @override
  void dispose() {
    _controller.dispose();
    _questionTimer?.cancel();
    super.dispose();
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _loadQuestions() async {
    _cachedToken = await AuthService.getToken();

    if (_cachedToken == null) {
      print('No auth token found');
      return;
    }

    final fetched = await QuestionService.getQuestions(_cachedToken!);

    setState(() {
      questions      = fetched;
      questionNumber = 0;
      selectedoption = -1;
      score          = 0;
    });

    if (questions.isNotEmpty) _setTimer();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _nextQuestion() {
    if (questions.isEmpty) return;

    _controller.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        if (questionNumber < questions.length - 1) {
          questionNumber++;
          selectedoption = -1;
          _controller.forward();
        } else {
          _questionTimer?.cancel();
          if (_cachedToken != null) {
            QuestionService.submitTestScore(score, _cachedToken!);
          }
          _showCompletionDialog();
        }
      });
    });
  }

  // ── Answer submission ──────────────────────────────────────────────────────

  // Fire-and-forget — UI responds instantly.
  // Return value (correct/incorrect) will be used later for weighted scoring.
  void _submitAnswerInBackground(int questionId, int selectedIndex) {
    if (_cachedToken == null) return;
    QuestionService.submitAnswer(questionId, selectedIndex, _cachedToken!);
  }

  // ── Timer ──────────────────────────────────────────────────────────────────

  void _setTimer() {
    _questionTimer?.cancel();
    seconds = 10;

    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (seconds < 1) {
          timer.cancel();
          _nextQuestion();
          if (questionNumber < questions.length) _setTimer();
        } else {
          seconds--;
        }
      });
    });
  }

  // ── Completion dialog ──────────────────────────────────────────────────────

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.celebration, color: Colors.amber, size: 28),
            SizedBox(width: 12),
            Text(
              'Quiz Completed!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Your Score', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryA, AppColors.primaryB],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$score / ${questions.length}',
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              questions.isNotEmpty && score >= (questions.length * 0.7).ceil()
                  ? 'Great job!'
                  : 'Keep practicing!',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => HomeScreen()),
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryA),
            child: const Text('Go to Home Page'),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.softBg,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: false,
          title: const Text(
            'Quick Test',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final Question current = questions[questionNumber];
    final int total        = questions.length;
    final double progress  = (questionNumber + 1) / total;

    return Scaffold(
      backgroundColor: AppColors.softBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: const Text(
          'Quick Test',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _controller,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.2, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
          ),
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [

              // ── Progress bar ───────────────────────────────────────────
              QuestionProgressBar(
                questionNumber: questionNumber,
                total:          total,
                progress:       progress,
                primaryA:       AppColors.primaryA,
              ),
              const SizedBox(height: 20),

              // ── Question card ──────────────────────────────────────────
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primaryA.withOpacity(0.1),
                              AppColors.primaryB.withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.help_outline_rounded, color: AppColors.primaryB, size: 28),
                            const SizedBox(width: 12),
                            Text(
                              'seconds left: $seconds',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryB,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        current.text,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Options ────────────────────────────────────────────────
              ...List.generate(current.options.length, (optIndex) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: QuestionOptionTile(
                    text:       current.options[optIndex],
                    isSelected: selectedoption == optIndex,
                    primaryA:   AppColors.primaryA,
                    primaryB:   AppColors.primaryB,
                    onTap: () {
                      setState(() {
                        if (selectedoption != optIndex) {
                          selectedoption = optIndex;
                          if (selectedoption == current.correctIndex) {
                            score++;
                          }
                        }
                      });
                    },
                  ),
                );
              }),

              const SizedBox(height: 20),

              // ── Next / Finish button ───────────────────────────────────
              ElevatedButton(
                onPressed: selectedoption == -1
                    ? null
                    : () {
                        _submitAnswerInBackground(current.id, selectedoption);
                        _setTimer();
                        _nextQuestion();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryA,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      questionNumber < total - 1 ? 'Next Question' : 'Finish Quiz',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
