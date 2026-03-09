import 'dart:async';
import 'package:flutter/material.dart';
import '../models/diagnostic_question.dart';
import '../services/diagnostic_service.dart';
import '../widgets/diagnostic_progress_bar.dart';
import '../widgets/slider_question_widget.dart';
import '../widgets/attention_task_widget.dart';
import '../widgets/option_card_question_widget.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../home/pages/home_page.dart';

/// One-time onboarding diagnostic page shown after signup.
/// Walks the user through all 15 questions, each rendered with
/// a different UI based on its dimension:
///   screen_habits → SliderQuestionWidget
///   attention     → AttentionTaskWidget (timer/re-read/cards)
///   lifestyle     → OptionCardQuestionWidget
///   learning      → OptionCardQuestionWidget
class DiagnosticPage extends StatefulWidget {
  const DiagnosticPage({super.key});

  @override
  State<DiagnosticPage> createState() => _DiagnosticPageState();
}

class _DiagnosticPageState extends State<DiagnosticPage>
    with SingleTickerProviderStateMixin {
  List<DiagnosticQuestion> _questions = [];
  final List<DiagnosticAnswer> _answers = [];

  int _currentIndex = 0;
  bool _loading = true;
  bool _submitting = false;
  String? _cachedToken;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.08, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _slideController, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeIn));
    _load();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _cachedToken = await AuthService.getToken();
    if (_cachedToken == null) {
      setState(() => _loading = false);
      return;
    }
    final questions = await DiagnosticService.getQuestions(_cachedToken!);
    setState(() {
      _questions = questions;
      _loading = false;
    });
    _slideController.forward();
  }

  // Called by each widget when the user confirms their answer
  void _onAnswered(DiagnosticAnswer answer) {
    _answers.add(answer);

    if (_currentIndex < _questions.length - 1) {
      // Animate to next question
      _slideController.reverse().then((_) {
        if (!mounted) return;
        setState(() => _currentIndex++);
        _slideController.forward();
      });
    } else {
      // All 15 answered — submit
      _submitSession();
    }
  }

  Future<void> _submitSession() async {
    setState(() => _submitting = true);

    final focusScore = await DiagnosticService.submitSession(
      _answers,
      _cachedToken!,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    _showResultDialog(focusScore ?? 70.0);
  }

  void _showResultDialog(double score) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ResultDialog(score: score),
    ).then((_) {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => HomeScreen()),
          (route) => false,
        );
      }
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080D1A),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _submitting
                ? _SubmittingView()
                : _buildQuestionView(),
      ),
    );
  }

  Widget _buildQuestionView() {
    if (_questions.isEmpty) {
      return const Center(
        child: Text('Could not load questions.',
            style: TextStyle(color: Colors.white)),
      );
    }

    final q = _questions[_currentIndex];

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Header ─────────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryA, AppColors.primaryB],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Focus Assessment',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'One-time setup',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Progress bar ────────────────────────────────────────────
              DiagnosticProgressBar(
                current:   _currentIndex,
                total:     _questions.length,
                dimension: q.dimension,
              ),

              const SizedBox(height: 28),

              // ── Question text ───────────────────────────────────────────
              Text(
                q.questionText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 24),

              // ── Dimension-specific widget ───────────────────────────────
              _buildWidget(q),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWidget(DiagnosticQuestion q) {
    switch (q.dimension) {
      case DiagnosticDimension.screenHabits:
        return SliderQuestionWidget(
          key: ValueKey(q.id),
          question: q,
          onAnswered: _onAnswered,
        );

      case DiagnosticDimension.attention:
        return AttentionTaskWidget(
          key: ValueKey(q.id),
          question: q,
          onAnswered: _onAnswered,
        );

      case DiagnosticDimension.lifestyle:
      case DiagnosticDimension.learning:
        return OptionCardQuestionWidget(
          key: ValueKey(q.id),
          question: q,
          onAnswered: _onAnswered,
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Submitting overlay
// ─────────────────────────────────────────────────────────────────────────────
class _SubmittingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primaryA),
          const SizedBox(height: 24),
          const Text(
            'Calculating your Focus Score...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This only takes a moment',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Result dialog shown after submission
// ─────────────────────────────────────────────────────────────────────────────
class _ResultDialog extends StatelessWidget {
  final double score;
  const _ResultDialog({required this.score});

  String get _label {
    if (score >= 80) return 'Excellent Focus!';
    if (score >= 65) return 'Good Foundation';
    if (score >= 50) return 'Room to Grow';
    return 'Let\'s Start Rebuilding';
  }

  String get _sub {
    if (score >= 80) return 'Your habits show strong attention capacity.';
    if (score >= 65) return 'You have a solid base — small changes will go far.';
    if (score >= 50) return 'FocusPro will help you build better habits.';
    return 'Don\'t worry — that\'s exactly why you\'re here.';
  }

  Color get _color {
    if (score >= 80) return Colors.green;
    if (score >= 65) return AppColors.primaryA;
    if (score >= 50) return Colors.orange;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F1624),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Score circle
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [_color.withOpacity(0.8), _color],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _color.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      score.toStringAsFixed(0),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Focus Score',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            Text(
              _label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _sub,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryA,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Go to Dashboard',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
