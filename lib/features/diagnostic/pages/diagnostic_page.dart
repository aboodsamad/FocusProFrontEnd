import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/diagnostic_question.dart';
import '../services/diagnostic_service.dart';
import '../widgets/slider_question_widget.dart';
import '../widgets/attention_task_widget.dart';
import '../widgets/option_card_question_widget.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../home/pages/home_page.dart';
import '../../home/providers/user_provider.dart';

// ─── Dimension color palette ─────────────────────────────────────────────────
class _DimTheme {
  final Color primary;
  final Color secondary;
  final Color bg;
  final String label;
  final String category;
  final IconData icon;
  final String sciSource;
  const _DimTheme({
    required this.primary, required this.secondary, required this.bg,
    required this.label,   required this.category,  required this.icon,
    required this.sciSource,
  });
}

const Map<DiagnosticDimension, _DimTheme> _themes = {
  DiagnosticDimension.screenHabits: _DimTheme(
    primary:   Color(0xFFD946EF), secondary: Color(0xFF9333EA),
    bg:        Color(0xFF130020),
    label:     'Screen Habits',   category:  'SCREEN & SOCIAL MEDIA',
    icon:      Icons.phone_android_rounded,
    sciSource: 'Smartphone Addiction Scale (SAS-SV) · Kwon et al., 2013',
  ),
  DiagnosticDimension.attention: _DimTheme(
    primary:   Color(0xFF60A5FA), secondary: Color(0xFF6366F1),
    bg:        Color(0xFF00082A),
    label:     'Attention',       category:  'Attention & Cognition',
    icon:      Icons.psychology_rounded,
    sciSource: 'ASRS-v1.1 Attention Scale (WHO) · Kessler et al., 2005',
  ),
  DiagnosticDimension.lifestyle: _DimTheme(
    primary:   Color(0xFF34D399), secondary: Color(0xFF0D9488),
    bg:        Color(0xFF001A10),
    label:     'Lifestyle',       category:  'Lifestyle Factors',
    icon:      Icons.nights_stay_rounded,
    sciSource: 'Pittsburgh Sleep Quality Index (PSQI) · WHO Activity Guidelines',
  ),
  DiagnosticDimension.learning: _DimTheme(
    primary:   Color(0xFFFBBF24), secondary: Color(0xFFEA580C),
    bg:        Color(0xFF1A0E00),
    label:     'Learning',        category:  'Learning & Cognition',
    icon:      Icons.auto_stories_rounded,
    sciSource: 'Need for Cognition Scale (NCS) · Cacioppo & Petty, 1982',
  ),
};

// ─────────────────────────────────────────────────────────────────────────────

class DiagnosticPage extends StatefulWidget {
  final String? token;
  const DiagnosticPage({super.key, this.token});
  @override State<DiagnosticPage> createState() => _DiagnosticPageState();
}

class _DiagnosticPageState extends State<DiagnosticPage>
    with TickerProviderStateMixin {

  List<DiagnosticQuestion> _questions = [];
  final List<DiagnosticAnswer> _answers = [];
  int  _currentIndex = 0;
  bool _loading      = true;
  bool _submitting   = false;
  bool _showIntro    = true;
  String? _cachedToken;

  // slide animation for question transitions
  late AnimationController _slideCtrl;
  late Animation<Offset>   _slideAnim;
  late Animation<double>   _fadeAnim;

  // pulse for intro orb
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  // background color tween
  late AnimationController _bgCtrl;
  Color _bgFrom = const Color(0xFF060611);
  Color _bgTo   = const Color(0xFF060611);

  @override
  void initState() {
    super.initState();

    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _slideAnim = Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _fadeAnim  = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeIn));

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _bgCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

    _load();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _pulseCtrl.dispose();
    _bgCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _cachedToken = widget.token ?? await AuthService.getToken();
    // No token → still load fallback questions so the UI is fully usable
    final questions = _cachedToken != null
        ? await DiagnosticService.getQuestions(_cachedToken!)
        : DiagnosticService.getFallbackQuestions();
    setState(() { _questions = questions; _loading = false; });
  }

  void _startAssessment() {
    setState(() => _showIntro = false);
    _animateBg(_themes[_questions.first.dimension]!.bg);
    _slideCtrl.forward();
  }

  void _animateBg(Color target) {
    if (!mounted) return;
    final current = Color.lerp(_bgFrom, _bgTo, _bgCtrl.value) ?? _bgFrom;
    _bgFrom = current;
    _bgTo   = target;
    _bgCtrl.forward(from: 0);
  }

  void _onAnswered(DiagnosticAnswer answer) {
    _answers.add(answer);
    if (_currentIndex < _questions.length - 1) {
      _slideCtrl.reverse().then((_) {
        if (!mounted) return;
        setState(() => _currentIndex++);
        final nextDim = _questions[_currentIndex].dimension;
        _animateBg(_themes[nextDim]!.bg);
        _slideCtrl.forward();
      });
    } else {
      _submitSession();
    }
  }

  Future<void> _submitSession() async {
    setState(() => _submitting = true);
    final score = await DiagnosticService.submitSession(_answers, _questions, _cachedToken!);
    if (!mounted) return;
    setState(() => _submitting = false);
    _showResultDialog(score ?? 70.0);
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
          MaterialPageRoute(builder: (_) => const HomeScreen()), (r) => false);
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bgCtrl,
      builder: (_, __) {
        final bg = Color.lerp(_bgFrom, _bgTo, _bgCtrl.value) ?? _bgFrom;
        return Scaffold(
          backgroundColor: bg,
          body: Stack(children: [
            // Animated glowing orbs
            if (!_showIntro && _questions.isNotEmpty)
              _OrbBackground(dimension: _questions[_currentIndex].dimension),

            SafeArea(
              child: _loading
                  ? _buildLoading()
                  : _submitting
                      ? _buildSubmitting()
                      : _showIntro
                          ? _buildIntro()
                          : _buildQuestion(),
            ),
          ]),
        );
      },
    );
  }

  // ── Loading ───────────────────────────────────────────────────────────────
  Widget _buildLoading() => Center(
    child: ScaleTransition(
      scale: _pulseAnim,
      child: Container(
        width: 88, height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: [AppColors.primaryA, AppColors.primaryB]),
          boxShadow: [BoxShadow(color: AppColors.primaryA.withOpacity(0.5), blurRadius: 36, spreadRadius: 6)],
        ),
        child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 42),
      ),
    ),
  );

  // ── Submitting ────────────────────────────────────────────────────────────
  Widget _buildSubmitting() => const Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      CircularProgressIndicator(color: Color(0xFF34D399), strokeWidth: 2.5),
      SizedBox(height: 20),
      Text('Calculating your Focus Score…',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
    ]),
  );

  // ── INTRO ─────────────────────────────────────────────────────────────────
  Widget _buildIntro() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [

        // Pulsing orb
        ScaleTransition(
          scale: _pulseAnim,
          child: Container(
            width: 130, height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.55), blurRadius: 60, spreadRadius: 8),
              ],
            ),
            child: const Center(child: Text('🧬', style: TextStyle(fontSize: 58))),
          ),
        ),

        const SizedBox(height: 24),

        // Eyebrow
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: const Text('SCIENCE-BACKED · 15 QUESTIONS',
              style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
        ),

        const SizedBox(height: 18),

        const Text('Know your\nfocus',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 46, fontWeight: FontWeight.w900,
              height: 1.05, letterSpacing: -2)),

        const SizedBox(height: 12),

        Text(
          'We measure your attention, screen habits,\nsleep and learning using validated\npsychological scales — not guesswork.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14, height: 1.7),
        ),

        const SizedBox(height: 30),

        // Stats row
        Row(children: [
          _statCard('${_questions.isEmpty ? "–" : _questions.length}', 'Questions', Icons.quiz_outlined),
          const SizedBox(width: 10),
          _statCard('~3', 'Minutes', Icons.timer_outlined),
          const SizedBox(width: 10),
          _statCard('4', 'Dimensions', Icons.layers_outlined),
        ]),

        const SizedBox(height: 20),

        // Dimension chips
        Wrap(spacing: 8, runSpacing: 8, children: [
          _dimChip('📱  Screen Habits', const Color(0xFFD946EF)),
          _dimChip('🧠  Attention',     const Color(0xFF60A5FA)),
          _dimChip('🌿  Lifestyle',     const Color(0xFF34D399)),
          _dimChip('✨  Learning',      const Color(0xFFFBBF24)),
        ]),

        const SizedBox(height: 36),

        // CTA
        GestureDetector(
          onTap: _questions.isEmpty ? null : _startAssessment,
          child: Container(
            width: double.infinity, height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.25), blurRadius: 40, offset: const Offset(0, 12))],
            ),
            child: const Center(
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('Begin Assessment',
                    style: TextStyle(color: Colors.black, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
                SizedBox(width: 10),
                Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 20),
              ]),
            ),
          ),
        ),

        const SizedBox(height: 14),
        Text('🔐  Your results are private and never shared',
            style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11)),
      ]),
    );
  }

  Widget _statCard(String val, String label, IconData icon) => Expanded(
    child: _glassBox(
      borderRadius: BorderRadius.circular(18),
      color: Colors.white.withOpacity(0.07),
      border: Border.all(color: Colors.white.withOpacity(0.1)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(children: [
          Icon(icon, color: Colors.white54, size: 18),
          const SizedBox(height: 7),
          Text(val, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10, fontWeight: FontWeight.w700)),
        ]),
      ),
    ),
  );

  Widget _dimChip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
  );

  // ── QUESTION VIEW ─────────────────────────────────────────────────────────
  Widget _buildQuestion() {
    if (_questions.isEmpty) return const Center(child: Text('Could not load questions.', style: TextStyle(color: Colors.white)));

    final q     = _questions[_currentIndex];
    final theme = _themes[q.dimension]!;

    return Column(children: [
      // ── Top bar ────────────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
        child: Row(children: [
          // Dimension chip
          _glassBox(
            borderRadius: BorderRadius.circular(30),
            color: theme.primary.withOpacity(0.15),
            border: Border.all(color: theme.primary.withOpacity(0.3)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: theme.primary)),
                const SizedBox(width: 7),
                Text(theme.label, style: TextStyle(color: theme.primary, fontSize: 12, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
          const Spacer(),
          // Counter
          _glassBox(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withOpacity(0.08),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: RichText(text: TextSpan(children: [
                TextSpan(text: '${_currentIndex + 1}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                TextSpan(text: ' / ${_questions.length}',
                    style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13)),
              ])),
            ),
          ),
        ]),
      ),

      const SizedBox(height: 10),

      // ── Segmented progress bar ─────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: List.generate(_questions.length, (i) {
            Color c;
            if (i < _currentIndex)      c = theme.primary.withOpacity(0.7);
            else if (i == _currentIndex) c = theme.primary;
            else                         c = Colors.white.withOpacity(0.08);
            return Expanded(
              child: Container(
                height: 4, margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: i == _currentIndex
                      ? [BoxShadow(color: theme.primary.withOpacity(0.6), blurRadius: 8)]
                      : null,
                ),
              ),
            );
          }),
        ),
      ),

      const SizedBox(height: 16),

      // ── Scrollable content ─────────────────────────────────────────────
      Expanded(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // ── Question card ─────────────────────────────────────
                _glassBox(
                  borderRadius: BorderRadius.circular(28),
                  color: Colors.white.withOpacity(0.08),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // Science source badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.science_outlined, size: 10, color: Colors.white.withOpacity(0.3)),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text('Validated by: ${theme.sciSource}',
                                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
                            ),
                          ]),
                        ),

                        const SizedBox(height: 16),

                        // Category label
                        Text(theme.category,
                            style: TextStyle(
                                color: theme.primary.withOpacity(0.7),
                                fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),

                        const SizedBox(height: 10),

                        // Question text
                        Text(q.questionText,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 21,
                                fontWeight: FontWeight.w800, height: 1.35, letterSpacing: -0.4)),
                      ]),
                    ),
                  ),

                const SizedBox(height: 14),

                // ── Answer widget ──────────────────────────────────────
                _buildAnswerWidget(q, theme),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildAnswerWidget(DiagnosticQuestion q, _DimTheme theme) {
    switch (q.dimension) {
      case DiagnosticDimension.screenHabits:
        return SliderQuestionWidget(key: ValueKey(q.id), question: q, onAnswered: _onAnswered);
      case DiagnosticDimension.attention:
        return AttentionTaskWidget(key: ValueKey(q.id), question: q, onAnswered: _onAnswered);
      case DiagnosticDimension.lifestyle:
      case DiagnosticDimension.learning:
        return OptionCardQuestionWidget(key: ValueKey(q.id), question: q, onAnswered: _onAnswered);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated orb background per dimension
// ─────────────────────────────────────────────────────────────────────────────
class _OrbBackground extends StatefulWidget {
  final DiagnosticDimension dimension;
  const _OrbBackground({required this.dimension});
  @override State<_OrbBackground> createState() => _OrbBackgroundState();
}

class _OrbBackgroundState extends State<_OrbBackground> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme = _themes[widget.dimension]!;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value * 2 * 3.14159;
        final ox1 = 60.0 * (1 + 0.4 * _sin(t * 0.7));
        final oy1 = 80.0 * (1 + 0.3 * _cos(t * 0.5));
        final ox2 = MediaQuery.of(context).size.width - 80 + 50 * _sin(t * 0.6 + 1.5);
        final oy2 = MediaQuery.of(context).size.height - 120 + 60 * _cos(t * 0.4 + 0.8);
        return Stack(children: [
          Positioned(left: ox1 - 130, top: oy1 - 130,
            child: _Orb(color: theme.primary, size: 260, opacity: 0.45)),
          Positioned(left: ox2 - 110, top: oy2 - 110,
            child: _Orb(color: theme.secondary, size: 220, opacity: 0.35)),
        ]);
      },
    );
  }
  double _sin(double x) => (x % (2 * 3.14159) < 3.14159) ? (x % 3.14159 / 3.14159) * 2 - 1 : 1 - (x % 3.14159 / 3.14159) * 2;
  double _cos(double x) => _sin(x + 3.14159 / 2);
}

class _Orb extends StatelessWidget {
  final Color color;
  final double size, opacity;
  const _Orb({required this.color, required this.size, required this.opacity});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color.withOpacity(opacity), Colors.transparent]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Web-safe glass container — skips BackdropFilter on web (html renderer)
// ─────────────────────────────────────────────────────────────────────────────
Widget _glassBox({
  required Widget child,
  required BorderRadius borderRadius,
  required Color color,
  Border? border,
  List<BoxShadow>? boxShadow,
}) {
  final decoration = BoxDecoration(
    color: color,
    borderRadius: borderRadius,
    border: border,
    boxShadow: boxShadow,
  );
  if (kIsWeb) {
    return Container(decoration: decoration, child: child);
  }
  return ClipRRect(
    borderRadius: borderRadius,
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
      child: Container(decoration: decoration, child: child),
    ),
  );
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
    if (score >= 65) return 'You have a solid base — small changes will go far.';
    if (score >= 50) return 'FocusPro will help you build better habits.';
    return "Don't worry — that's exactly why you're here.";
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [_color, _color.withOpacity(0.7)]),
              boxShadow: [BoxShadow(color: _color.withOpacity(0.5), blurRadius: 36, spreadRadius: 6)],
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: score),
                duration: const Duration(milliseconds: 1400),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => Text(v.toStringAsFixed(0),
                    style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900, height: 1)),
              ),
              const SizedBox(height: 2),
              Text('Focus Score', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
            ]),
          ),
          const SizedBox(height: 22),
          Text(_label, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(_sub, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[400], fontSize: 14, height: 1.55)),
          const SizedBox(height: 26),
          Divider(color: Colors.white.withOpacity(0.06)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity, height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('Go to Dashboard',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 18),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
