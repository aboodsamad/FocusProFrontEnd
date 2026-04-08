import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/diagnostic_question.dart';
import '../services/diagnostic_service.dart';
import '../widgets/diagnostic_progress_bar.dart';
import '../widgets/slider_question_widget.dart';
import '../widgets/attention_task_widget.dart';
import '../widgets/option_card_question_widget.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../home/pages/home_page.dart';
import '../../home/providers/user_provider.dart';

class DiagnosticPage extends StatefulWidget {
  final String? token;
  const DiagnosticPage({super.key, this.token});

  @override
  State<DiagnosticPage> createState() => _DiagnosticPageState();
}

class _DiagnosticPageState extends State<DiagnosticPage>
    with TickerProviderStateMixin {
  List<DiagnosticQuestion> _questions = [];
  final List<DiagnosticAnswer> _answers = [];

  int _currentIndex = 0;
  bool _loading = true;
  bool _submitting = false;
  bool _showIntro = true;
  String? _cachedToken;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _slideController, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeIn));

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _load();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _cachedToken = widget.token ?? await AuthService.getToken();
    if (_cachedToken == null) {
      setState(() => _loading = false);
      return;
    }
    final questions = await DiagnosticService.getQuestions(_cachedToken!);
    setState(() {
      _questions = questions;
      _loading = false;
    });
  }

  void _startAssessment() {
    setState(() => _showIntro = false);
    _slideController.forward();
  }

  void _onAnswered(DiagnosticAnswer answer) {
    _answers.add(answer);
    if (_currentIndex < _questions.length - 1) {
      _slideController.reverse().then((_) {
        if (!mounted) return;
        setState(() => _currentIndex++);
        _slideController.forward();
      });
    } else {
      _submitSession();
    }
  }

  Future<void> _submitSession() async {
    setState(() => _submitting = true);
    final focusScore = await DiagnosticService.submitSession(
      _answers,
      _questions,
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
        context.read<UserProvider>().updateFocusScore(score);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08091A),
      body: Stack(
        children: [
          _buildDecorativeBackground(),
          SafeArea(
            child: _loading
                ? _buildLoadingView()
                : _submitting
                    ? _buildSubmittingView()
                    : _showIntro
                        ? _buildIntroScreen()
                        : _buildQuestionView(),
          ),
        ],
      ),
    );
  }

  // ── Decorative background blobs ──────────────────────────────────────────
  Widget _buildDecorativeBackground() {
    return Stack(
      children: [
        Positioned(
          top: -120,
          right: -80,
          child: Container(
            width: 340,
            height: 340,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primaryB.withOpacity(0.25),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -140,
          left: -100,
          child: Container(
            width: 360,
            height: 360,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primaryA.withOpacity(0.18),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Loading ───────────────────────────────────────────────────────────────
  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.primaryA, AppColors.primaryB],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryA.withOpacity(0.55),
                    blurRadius: 40,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: const Icon(Icons.psychology_rounded,
                  color: Colors.white, size: 46),
            ),
          ),
          const SizedBox(height: 32),
          const Text('Preparing your assessment',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Just a moment...',
              style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          const SizedBox(height: 32),
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
                color: AppColors.primaryA, strokeWidth: 2.5),
          ),
        ],
      ),
    );
  }

  // ── Submitting ───────────────────────────────────────────────────────────
  Widget _buildSubmittingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF34D399), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF34D399).withOpacity(0.45),
                  blurRadius: 40,
                  spreadRadius: 6,
                ),
              ],
            ),
            child: const Icon(Icons.analytics_rounded,
                color: Colors.white, size: 46),
          ),
          const SizedBox(height: 32),
          const Text('Calculating your Focus Score',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Analyzing your responses...',
              style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          const SizedBox(height: 32),
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
                color: const Color(0xFF34D399), strokeWidth: 2.5),
          ),
        ],
      ),
    );
  }

  // ── INTRO SCREEN ─────────────────────────────────────────────────────────
  Widget _buildIntroScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Hero icon
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.primaryA, AppColors.primaryB],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryA.withOpacity(0.6),
                    blurRadius: 48,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: const Icon(Icons.psychology_rounded,
                  color: Colors.white, size: 58),
            ),
          ),

          const SizedBox(height: 32),

          // Badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.primaryA, AppColors.primaryB]),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryA.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Text('Focus Assessment',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.4)),
          ),

          const SizedBox(height: 22),

          // Headline
          const Text(
            "Let's discover\nyour focus profile",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.bold,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 14),

          Text(
            'Answer honestly — no right or wrong answers.\nWe personalise your entire experience from this.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 15,
              height: 1.6,
            ),
          ),

          const SizedBox(height: 36),

          // Stats row
          Row(
            children: [
              _statCard(Icons.quiz_outlined,
                  _questions.isEmpty ? '–' : '${_questions.length}',
                  'Questions', const Color(0xFF818CF8)),
              const SizedBox(width: 10),
              _statCard(Icons.timer_outlined, '~3', 'Minutes',
                  const Color(0xFF34D399)),
              const SizedBox(width: 10),
              _statCard(Icons.lock_outline_rounded, '1×', 'Only Once',
                  Colors.orange),
            ],
          ),

          const SizedBox(height: 28),

          // Dimension chips
          Align(
            alignment: Alignment.centerLeft,
            child: Text('We will assess',
                style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _dimChip('📱  Screen Habits', Colors.pinkAccent),
              _dimChip('🧠  Attention', AppColors.primaryA),
              _dimChip('😴  Lifestyle', const Color(0xFF34D399)),
              _dimChip('📚  Learning', Colors.orange),
            ],
          ),

          const SizedBox(height: 48),

          // CTA button
          GestureDetector(
            onTap: _questions.isEmpty ? null : _startAssessment,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                gradient: _questions.isEmpty
                    ? LinearGradient(
                        colors: [Colors.grey[800]!, Colors.grey[800]!])
                    : const LinearGradient(
                        colors: [AppColors.primaryA, AppColors.primaryB],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: _questions.isEmpty
                    ? null
                    : [
                        BoxShadow(
                          color: AppColors.primaryA.withOpacity(0.55),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
              ),
              child: const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Begin Assessment",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2)),
                    SizedBox(width: 10),
                    Icon(Icons.arrow_forward_rounded,
                        color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          Text('Your results are private and never shared',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700], fontSize: 12)),
        ],
      ),
    );
  }

  Widget _statCard(
      IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _dimChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    );
  }

  // ── QUESTION VIEW ─────────────────────────────────────────────────────────
  Widget _buildQuestionView() {
    if (_questions.isEmpty) {
      return const Center(
        child: Text('Could not load questions.',
            style: TextStyle(color: Colors.white)),
      );
    }
    final q = _questions[_currentIndex];
    final dimColor = _dimColor(q.dimension);

    return Column(
      children: [
        // ── Sticky header ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF08091A).withOpacity(0.95),
            border: Border(
                bottom: BorderSide(
                    color: Colors.white.withOpacity(0.06), width: 1)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Dimension chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: dimColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: dimColor.withOpacity(0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_dimIcon(q.dimension),
                            color: dimColor, size: 12),
                        const SizedBox(width: 5),
                        Text(_dimLabel(q.dimension),
                            style: TextStyle(
                                color: dimColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Question counter pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: RichText(
                      text: TextSpan(children: [
                        TextSpan(
                          text: '${_currentIndex + 1}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                        TextSpan(
                          text: ' / ${_questions.length}',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 13),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DiagnosticProgressBar(
                current: _currentIndex,
                total: _questions.length,
                dimension: q.dimension,
              ),
            ],
          ),
        ),

        // ── Scrollable content ────────────────────────────────────────────
        Expanded(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            dimColor.withOpacity(0.12),
                            dimColor.withOpacity(0.04),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: dimColor.withOpacity(0.25),
                            width: 1.5),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 4,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  dimColor,
                                  dimColor.withOpacity(0.2)
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              q.questionText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        _dimHint(q.dimension),
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 12),
                      ),
                    ),

                    const SizedBox(height: 24),

                    _buildWidget(q),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _dimColor(DiagnosticDimension d) {
    switch (d) {
      case DiagnosticDimension.screenHabits:
        return Colors.pinkAccent;
      case DiagnosticDimension.attention:
        return const Color(0xFF818CF8);
      case DiagnosticDimension.lifestyle:
        return const Color(0xFF34D399);
      case DiagnosticDimension.learning:
        return Colors.orange;
    }
  }

  IconData _dimIcon(DiagnosticDimension d) {
    switch (d) {
      case DiagnosticDimension.screenHabits:
        return Icons.phone_android_rounded;
      case DiagnosticDimension.attention:
        return Icons.psychology_rounded;
      case DiagnosticDimension.lifestyle:
        return Icons.nights_stay_rounded;
      case DiagnosticDimension.learning:
        return Icons.auto_stories_rounded;
    }
  }

  String _dimLabel(DiagnosticDimension d) {
    switch (d) {
      case DiagnosticDimension.screenHabits:
        return 'Screen Habits';
      case DiagnosticDimension.attention:
        return 'Attention';
      case DiagnosticDimension.lifestyle:
        return 'Lifestyle';
      case DiagnosticDimension.learning:
        return 'Learning';
    }
  }

  String _dimHint(DiagnosticDimension d) {
    switch (d) {
      case DiagnosticDimension.screenHabits:
        return 'Be honest — this helps us understand your baseline.';
      case DiagnosticDimension.attention:
        return 'Choose the answer that feels most true.';
      case DiagnosticDimension.lifestyle:
        return 'Think about your average day.';
      case DiagnosticDimension.learning:
        return 'Think about your average week.';
    }
  }

  Widget _buildWidget(DiagnosticQuestion q) {
    switch (q.dimension) {
      case DiagnosticDimension.screenHabits:
        return SliderQuestionWidget(
            key: ValueKey(q.id),
            question: q,
            onAnswered: _onAnswered);
      case DiagnosticDimension.attention:
        return AttentionTaskWidget(
            key: ValueKey(q.id),
            question: q,
            onAnswered: _onAnswered);
      case DiagnosticDimension.lifestyle:
      case DiagnosticDimension.learning:
        return OptionCardQuestionWidget(
            key: ValueKey(q.id),
            question: q,
            onAnswered: _onAnswered);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Result dialog
// ─────────────────────────────────────────────────────────────────────────────
class _ResultDialog extends StatelessWidget {
  final double score;
  const _ResultDialog({required this.score});

  String get _label {
    if (score >= 80) return 'Excellent Focus!';
    if (score >= 65) return 'Good Foundation';
    if (score >= 50) return 'Room to Grow';
    return "Let's Start Rebuilding";
  }

  String get _sub {
    if (score >= 80) return 'Your habits show strong attention capacity.';
    if (score >= 65)
      return 'You have a solid base — small changes will go far.';
    if (score >= 50) return 'FocusPro will help you build better habits.';
    return "Don't worry — that's exactly why you're here.";
  }

  String get _emoji {
    if (score >= 80) return '🏆';
    if (score >= 65) return '🎯';
    if (score >= 50) return '🌱';
    return '🔥';
  }

  Color get _color {
    if (score >= 80) return const Color(0xFF34D399);
    if (score >= 65) return AppColors.primaryA;
    if (score >= 50) return Colors.orange;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F1624),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Score circle with glow
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    colors: [_color.withOpacity(0.85), _color],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                boxShadow: [
                  BoxShadow(
                      color: _color.withOpacity(0.55),
                      blurRadius: 36,
                      spreadRadius: 6),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: score),
                    duration: const Duration(milliseconds: 1400),
                    curve: Curves.easeOutCubic,
                    builder: (_, val, __) => Text(
                      val.toStringAsFixed(0),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 44,
                          fontWeight: FontWeight.bold,
                          height: 1),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('Focus Score',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('$_emoji  $_label',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(_sub,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                    height: 1.55)),
            const SizedBox(height: 28),
            Container(height: 1, color: Colors.white.withOpacity(0.07)),
            const SizedBox(height: 22),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [_color, _color.withOpacity(0.75)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _color.withOpacity(0.45),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Go to Dashboard',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 18),
                    ],
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
