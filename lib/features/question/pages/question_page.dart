import 'dart:async';
import 'package:capstone_front_end/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';
import '../models/question.dart';
import '../services/question_service.dart';
import '../../home/pages/home_page.dart';

class QuestionPage extends StatefulWidget {
  const QuestionPage({super.key});
  @override State<QuestionPage> createState() => _QuestionPageState();
}

class _QuestionPageState extends State<QuestionPage>
    with SingleTickerProviderStateMixin {

  late AnimationController _slideCtrl;
  int _selected  = -1;
  int _qIndex    = 0;
  int _score     = 0;
  int _seconds   = 10;
  Timer? _timer;
  String? _token;
  List<Question> _questions = [];

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _slideCtrl.forward();
    _loadQuestions();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────
  Future<void> _loadQuestions() async {
    _token = await AuthService.getToken();
    if (_token == null) return;
    final q = await QuestionService.getQuestions(_token!);
    setState(() { _questions = q; _qIndex = 0; _selected = -1; _score = 0; });
    if (_questions.isNotEmpty) _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _seconds = 10;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_seconds <= 1) { t.cancel(); _next(); }
        else _seconds--;
      });
    });
  }

  void _next() {
    if (_questions.isEmpty) return;
    _slideCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        if (_qIndex < _questions.length - 1) {
          _qIndex++;
          _selected = -1;
          _slideCtrl.forward();
          _startTimer();
        } else {
          _timer?.cancel();
          if (_token != null) QuestionService.submitTestScore(_score, _token!);
          _showResult();
        }
      });
    });
  }

  // ── Timer color ────────────────────────────────────────────────────────────
  Color get _timerColor {
    if (_seconds > 6) return AppColors.secondary;
    if (_seconds > 3) return const Color(0xFFF59E0B);
    return AppColors.error;
  }

  // ── Result dialog ──────────────────────────────────────────────────────────
  void _showResult() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 96, height: 96,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryContainer,
              ),
              child: Center(child: Text(
                '$_score/${_questions.length}',
                style: const TextStyle(
                    color: AppColors.onPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w900),
              )),
            ),
            const SizedBox(height: 20),
            const Text('Challenge Complete!',
                style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(
              _questions.isNotEmpty &&
                      _score >= (_questions.length * 0.7).ceil()
                  ? 'Excellent neural performance!'
                  : 'Keep training your mind!',
              style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (_) => HomeScreen())),
              child: Container(
                width: double.infinity, height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Center(
                  child: Text('Back to Hub',
                      style: TextStyle(
                          color: AppColors.onPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final q             = _questions[_qIndex];
    final timerFraction = _seconds / 10.0;
    final progress      = (_qIndex + 1) / _questions.length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(children: [

          // ── Minimal header ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(children: [
              Text('FocusPro',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: -0.5,
                  )),
              const Spacer(),
              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Exit'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.onSurfaceVariant,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 20),

          // ── Progress ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ASSESSMENT PHASE',
                    style: TextStyle(
                      color: AppColors.secondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    'Step ${_qIndex + 1} of ${_questions.length}',
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.surfaceContainerHigh,
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  minHeight: 6,
                ),
              ),
            ]),
          ),

          const SizedBox(height: 4),

          // ── Timer bar ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              height: 3,
              child: Stack(children: [
                Container(color: AppColors.surfaceContainer),
                FractionallySizedBox(
                  widthFactor: timerFraction,
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 800),
                    color: _timerColor,
                  ),
                ),
              ]),
            ),
          ),

          const SizedBox(height: 24),

          // ── Scrollable content ─────────────────────────────────────────
          Expanded(
            child: FadeTransition(
              opacity: CurvedAnimation(parent: _slideCtrl, curve: Curves.easeIn),
              child: SlideTransition(
                position: Tween<Offset>(
                        begin: const Offset(0.06, 0), end: Offset.zero)
                    .animate(CurvedAnimation(
                        parent: _slideCtrl, curve: Curves.easeOutCubic)),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Question text
                      Text(q.text,
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              height: 1.3,
                              letterSpacing: -0.5)),

                      const SizedBox(height: 8),

                      Text(
                        'Understanding your baseline helps calibrate your sessions.',
                        style: TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Answer options
                      ...List.generate(q.options.length, (i) {
                        final isSelected = _selected == i;
                        final icons = [
                          Icons.verified_user_outlined,
                          Icons.filter_vintage_outlined,
                          Icons.psychology_outlined,
                          Icons.storm_outlined,
                        ];
                        final icon = i < icons.length ? icons[i] : Icons.circle_outlined;

                        return GestureDetector(
                          onTap: () => setState(() {
                            if (_selected != i) {
                              _selected = i;
                              if (i == q.correctIndex) _score++;
                            }
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primaryContainer
                                  : AppColors.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(16),
                              border: isSelected
                                  ? Border.all(color: AppColors.primary, width: 2)
                                  : null,
                            ),
                            child: Row(children: [
                              // Icon container
                              Container(
                                width: 48, height: 48,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(child: Icon(
                                  isSelected ? Icons.check_circle : icon,
                                  color: isSelected
                                      ? AppColors.onPrimary
                                      : AppColors.onSurface,
                                  size: 22,
                                )),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(q.options[i],
                                        style: TextStyle(
                                            color: isSelected
                                                ? AppColors.onPrimary
                                                : AppColors.onSurface,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle,
                                    color: AppColors.onPrimary, size: 20),
                            ]),
                          ),
                        );
                      }),

                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Footer actions ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Row(children: [
              if (_qIndex > 0)
                TextButton.icon(
                  onPressed: () {
                    _slideCtrl.reverse().then((_) {
                      if (!mounted) return;
                      setState(() { _qIndex--; _selected = -1; });
                      _slideCtrl.forward();
                      _startTimer();
                    });
                  },
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Previous'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.onSurfaceVariant,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              const Spacer(),
              GestureDetector(
                onTap: _selected == -1
                    ? null
                    : () {
                        if (_token != null) {
                          QuestionService.submitAnswer(q.id, _selected, _token!);
                        }
                        _next();
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: _selected == -1
                        ? AppColors.surfaceContainerHigh
                        : AppColors.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _qIndex < _questions.length - 1 ? 'Continue' : 'Finish',
                    style: TextStyle(
                        color: _selected == -1
                            ? AppColors.onSurfaceVariant
                            : AppColors.onPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ]),
          ),

        ]),
      ),
    );
  }
}
