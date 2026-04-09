import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';
import '../models/question.dart';
import '../services/question_service.dart';
import '../../home/pages/home_page.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _bg      = Color(0xFF080B14);
const _cardBg  = Color(0xFF0F1524);
const _purple  = Color(0xFF8B5CF6);
const _violet  = Color(0xFFA78BFA);

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
    if (_seconds > 6) return const Color(0xFF34D399);
    if (_seconds > 3) return const Color(0xFFFBBF24);
    return const Color(0xFFEF4444);
  }

  // ── Result dialog ──────────────────────────────────────────────────────────
  void _showResult() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                    colors: [_purple, _violet],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                boxShadow: [BoxShadow(
                    color: _purple.withOpacity(0.45),
                    blurRadius: 28, spreadRadius: 4)],
              ),
              child: Center(child: Text(
                '$_score/${_questions.length}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900),
              )),
            ),
            const SizedBox(height: 20),
            const Text('Challenge Complete!',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(
              _questions.isNotEmpty &&
                      _score >= (_questions.length * 0.7).ceil()
                  ? 'Excellent neural performance!'
                  : 'Keep training your mind!',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (_) => HomeScreen())),
              child: Container(
                width: double.infinity, height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_purple, _violet]),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(
                      color: _purple.withOpacity(0.4),
                      blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: const Center(
                  child: Text('Back to Hub',
                      style: TextStyle(
                          color: Colors.white,
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
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _purple)),
      );
    }

    final q              = _questions[_qIndex];
    final timerFraction  = _seconds / 10.0;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [

            // ── Full-width timer bar ───────────────────────────────────────
            SizedBox(
              height: 4,
              child: Stack(children: [
                Container(color: Colors.white.withOpacity(0.06)),
                FractionallySizedBox(
                  widthFactor: timerFraction,
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 800),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [_timerColor, _timerColor.withOpacity(0.7)]),
                      boxShadow: [BoxShadow(
                          color: _timerColor.withOpacity(0.6), blurRadius: 6)],
                    ),
                  ),
                ),
              ]),
            ),

            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: Row(children: [
                const Icon(Icons.psychology_rounded, color: _purple, size: 22),
                const SizedBox(width: 8),
                const Text('FocusPro',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18)),
                const Spacer(),
                const Icon(Icons.notifications_outlined,
                    color: Colors.white38, size: 22),
              ]),
            ),

            const SizedBox(height: 20),

            // ── Progress & Score row ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('PROGRESS',
                        style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 10,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('Q${_qIndex + 1}/${_questions.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            height: 1)),
                  ]),
                  const Spacer(),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('CURRENT SCORE',
                        style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 10,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('${_score * 250}',
                        style: const TextStyle(
                            color: _violet,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            height: 1)),
                  ]),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ── Scrollable content ─────────────────────────────────────────
            Expanded(
              child: FadeTransition(
                opacity: CurvedAnimation(
                    parent: _slideCtrl, curve: Curves.easeIn),
                child: SlideTransition(
                  position: Tween<Offset>(
                          begin: const Offset(0.08, 0), end: Offset.zero)
                      .animate(CurvedAnimation(
                          parent: _slideCtrl, curve: Curves.easeOutCubic)),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Column(children: [

                      // ── Question card ──────────────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: _cardBg,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.08)),
                          boxShadow: [BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 20, offset: const Offset(0, 8))],
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          // Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _purple.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: _purple.withOpacity(0.3)),
                            ),
                            child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _purple)),
                              const SizedBox(width: 6),
                              Text('COGNITIVE LOAD CHALLENGE',
                                  style: TextStyle(
                                      color: _violet,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2)),
                            ]),
                          ),
                          const SizedBox(height: 16),
                          Text(q.text,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  height: 1.4)),
                        ]),
                      ),

                      const SizedBox(height: 16),

                      // ── Answer options ─────────────────────────────────
                      ...List.generate(q.options.length, (i) {
                        final isSelected = _selected == i;
                        final letter = ['A', 'B', 'C', 'D'][i];
                        return GestureDetector(
                          onTap: () => setState(() {
                            if (_selected != i) {
                              _selected = i;
                              if (i == q.correctIndex) _score++;
                            }
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _purple.withOpacity(0.15)
                                  : _cardBg,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isSelected
                                    ? _purple
                                    : Colors.white.withOpacity(0.08),
                                width: isSelected ? 1.5 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [BoxShadow(
                                      color: _purple.withOpacity(0.25),
                                      blurRadius: 16)]
                                  : null,
                            ),
                            child: Row(children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 38, height: 38,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? _purple
                                      : Colors.white.withOpacity(0.07),
                                ),
                                child: Center(
                                  child: Text(letter,
                                      style: TextStyle(
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.grey[400],
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15)),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(q.options[i],
                                    style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.grey[300],
                                        fontSize: 15,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        height: 1.35)),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.check_circle_rounded,
                                    color: _purple, size: 20),
                              ],
                            ]),
                          ),
                        );
                      }),

                      const SizedBox(height: 12),
                    ]),
                  ),
                ),
              ),
            ),

            // ── Submit button (pinned to bottom) ───────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
              child: GestureDetector(
                onTap: _selected == -1
                    ? null
                    : () {
                        if (_token != null) {
                          QuestionService.submitAnswer(
                              q.id, _selected, _token!);
                        }
                        _next();
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: _selected == -1
                        ? LinearGradient(colors: [
                            Colors.grey[850]!,
                            Colors.grey[800]!
                          ])
                        : const LinearGradient(
                            colors: [_purple, _violet],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: _selected != -1
                        ? [BoxShadow(
                            color: _purple.withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6))]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      _qIndex < _questions.length - 1
                          ? 'SUBMIT ANSWER'
                          : 'FINISH CHALLENGE',
                      style: TextStyle(
                          color: _selected == -1
                              ? Colors.grey[600]
                              : Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2),
                    ),
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
