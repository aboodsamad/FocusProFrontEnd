import 'package:capstone_front_end/core/services/auth_service.dart';
import 'package:flutter/material.dart';
import '../models/ai_question_model.dart';
import '../services/ai_service.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _bg     = Color(0xFF080B14);
const _cardBg = Color(0xFF0F1524);
const _purple = Color(0xFF8B5CF6);
const _violet = Color(0xFFA78BFA);
const _green  = Color(0xFF34D399);
const _red    = Color(0xFFEF4444);
const _amber  = Color(0xFFFBBF24);

/// Full-page retention test.
/// Navigate to it like this (e.g. from home_page.dart or profile_page.dart):
///
/// ```dart
/// Navigator.push(context,
///   MaterialPageRoute(builder: (_) => const RetentionTestPage()));
/// ```
class RetentionTestPage extends StatefulWidget {
  const RetentionTestPage({super.key});

  @override
  State<RetentionTestPage> createState() => _RetentionTestPageState();
}

class _RetentionTestPageState extends State<RetentionTestPage>
    with SingleTickerProviderStateMixin {

  // ── State ─────────────────────────────────────────────────────────────────
  List<AiQuestionModel> _questions  = [];
  final Map<int, String> _answers   = {};
  int    _currentIndex              = 0;
  bool   _loading                   = true;
  bool   _submitting                = false;
  String? _error;
  RetentionTestResult? _result;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _loadTest();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────
Future<void> _loadTest() async {
  setState(() { _loading = true; _error = null; _answers.clear(); _currentIndex = 0; _result = null; });
  final token = await AuthService.getToken() ?? '';
  final q = await AiService.generateRetentionTest(token);
  if (!mounted) return;
  if (q.isEmpty) {
    setState(() {
      _loading = false;
      _error = 'Not enough completed snippets yet.\nFinish a few more snippets first!';
    });
    return;
  }
  setState(() { _questions = q; _loading = false; });
  _fadeCtrl.forward();
}

Future<void> _submit() async {
  if (_answers.length < _questions.length) return;
  setState(() => _submitting = true);
  final token = await AuthService.getToken() ?? '';
  final result = await AiService.submitRetentionTest(_answers, token);
  if (!mounted) return;
  setState(() { _submitting = false; _result = result; });
}

  void _nextQuestion() {
    _fadeCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() => _currentIndex++);
      _fadeCtrl.forward();
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: ShaderMask(
          shaderCallback: (b) => const LinearGradient(
              colors: [_purple, _violet]).createShader(b),
          child: const Text('Retention Test',
              style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        centerTitle: true,
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading)        return _buildLoading();
    if (_error != null)  return _buildError();
    if (_result != null) return _buildResult();
    return _buildQuestions();
  }

  // ── Loading ───────────────────────────────────────────────────────────────
  Widget _buildLoading() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
              colors: [_purple, _violet],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [BoxShadow(
              color: _purple.withOpacity(0.4), blurRadius: 28, spreadRadius: 4)],
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
        ),
      ),
      const SizedBox(height: 28),
      const Text('AI is building your retention test…',
          style: TextStyle(color: Colors.white70, fontSize: 15)),
      const SizedBox(height: 8),
      const Text('Pulling from your past reading',
          style: TextStyle(color: Colors.white38, fontSize: 13)),
    ]));
  }

  // ── Error ─────────────────────────────────────────────────────────────────
  Widget _buildError() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.menu_book_outlined, color: _violet, size: 64),
        const SizedBox(height: 20),
        Text(_error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.6)),
        const SizedBox(height: 32),
        _GradientButton(label: 'Go Back', onTap: () => Navigator.pop(context)),
      ]),
    ));
  }

  // ── Questions ─────────────────────────────────────────────────────────────
  Widget _buildQuestions() {
    final q      = _questions[_currentIndex];
    final isLast = _currentIndex == _questions.length - 1;
    final chosen = _answers[q.questionId];

    return FadeTransition(
      opacity: _fadeAnim,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Info banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _amber.withOpacity(0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.history_edu_outlined, color: _amber, size: 18),
              SizedBox(width: 10),
              Expanded(child: Text(
                  'These questions are based on snippets you read in the past. Your score may change.',
                  style: TextStyle(color: _amber, fontSize: 12, height: 1.4))),
            ]),
          ),

          const SizedBox(height: 20),

          // Progress
          Row(children: [
            Text('Question ${_currentIndex + 1} of ${_questions.length}',
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
            const Spacer(),
            Text('${_answers.length}/${_questions.length} answered',
                style: const TextStyle(color: _violet, fontSize: 13)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentIndex + 1) / _questions.length,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(_purple),
              minHeight: 4,
            ),
          ),

          const SizedBox(height: 20),

          // Question
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _purple.withOpacity(0.3)),
            ),
            child: Text(q.questionText,
                style: const TextStyle(
                    color: Colors.white, fontSize: 16, height: 1.55,
                    fontWeight: FontWeight.w500)),
          ),

          const SizedBox(height: 20),

          // Options
          for (final letter in ['A', 'B', 'C', 'D'])
            _OptionTile(
              letter: letter,
              text: q.optionText(letter),
              isSelected: chosen == letter,
              onTap: () => setState(() => _answers[q.questionId] = letter),
            ),

          const Spacer(),

          if (chosen != null)
            _GradientButton(
              label: isLast
                  ? (_submitting ? 'Submitting…' : 'Submit Test')
                  : 'Next Question',
              onTap: _submitting ? null : (isLast ? _submit : _nextQuestion),
            ),
        ]),
      ),
    );
  }

  // ── Result ────────────────────────────────────────────────────────────────
  Widget _buildResult() {
    final r      = _result!;
    final gained = r.scoreDelta > 0;
    final lost   = r.scoreDelta < 0;
    final color  = gained ? _green : lost ? _red : _amber;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(children: [

        // Score circle
        Container(
          width: 120, height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: gained
                  ? [_purple, _violet]
                  : lost
                      ? [_red, const Color(0xFFB91C1C)]
                      : [_amber, const Color(0xFFF59E0B)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            boxShadow: [BoxShadow(
                color: color.withOpacity(0.4), blurRadius: 32, spreadRadius: 6)],
          ),
          child: Center(child: Text(
            '${r.correctCount}/${r.totalQuestions}',
            style: const TextStyle(color: Colors.white, fontSize: 30,
                fontWeight: FontWeight.bold),
          )),
        ),

        const SizedBox(height: 20),

        Text(
          gained ? '🧠 Strong Retention!' : lost ? '😓 Needs Review' : '🙂 Decent Retention',
          style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 10),

        Text(r.message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),

        const SizedBox(height: 16),

        // Score delta chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(gained ? Icons.trending_up : lost ? Icons.trending_down : Icons.trending_flat,
                color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              gained
                  ? '+${r.scoreDelta.toStringAsFixed(1)} focus points'
                  : lost
                      ? '${r.scoreDelta.toStringAsFixed(1)} focus points'
                      : 'No score change',
              style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ]),
        ),

        const SizedBox(height: 8),

        Text('New focus score: ${r.newFocusScore.toStringAsFixed(1)}',
            style: const TextStyle(color: Colors.white38, fontSize: 13)),

        const SizedBox(height: 28),

        // Breakdown
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Question Breakdown',
              style: TextStyle(color: Colors.white,
                  fontSize: 15, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 12),

        for (int i = 0; i < r.results.length; i++)
          _ResultRow(index: i + 1, result: r.results[i], question: _questions[i]),

        const SizedBox(height: 28),

        _GradientButton(label: 'Back to App', onTap: () => Navigator.pop(context)),
      ]),
    );
  }
}

// ── Option tile ───────────────────────────────────────────────────────────────
class _OptionTile extends StatelessWidget {
  final String letter;
  final String text;
  final bool   isSelected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.letter, required this.text,
    required this.isSelected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: isSelected
              ? const LinearGradient(colors: [_purple, _violet]) : null,
          color: isSelected ? null : _cardBg,
          border: Border.all(
              color: isSelected ? Colors.transparent : Colors.white12, width: 1.5),
        ),
        child: Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? Colors.white24 : Colors.white10,
            ),
            child: Center(child: Text(letter,
                style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white54,
                    fontWeight: FontWeight.bold, fontSize: 13))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(text,
              style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 14, height: 1.4))),
          if (isSelected)
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
        ]),
      ),
    );
  }
}

// ── Result row ────────────────────────────────────────────────────────────────
class _ResultRow extends StatelessWidget {
  final int             index;
  final AiAnswerResult  result;
  final AiQuestionModel question;

  const _ResultRow({
      required this.index, required this.result, required this.question});

  @override
  Widget build(BuildContext context) {
    final correct = result.correct;
    final color   = correct ? _green : _red;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(correct ? Icons.check_circle : Icons.cancel, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('Q$index: ${question.questionText}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              maxLines: 2, overflow: TextOverflow.ellipsis)),
        ]),
        if (!correct) ...[
          const SizedBox(height: 8),
          Text('Your answer:    ${result.chosenAnswer} — ${question.optionText(result.chosenAnswer)}',
              style: const TextStyle(color: _red, fontSize: 12)),
          Text('Correct answer: ${result.correctAnswer} — ${question.optionText(result.correctAnswer)}',
              style: const TextStyle(color: _green, fontSize: 12)),
        ],
      ]),
    );
  }
}

// ── Gradient button ───────────────────────────────────────────────────────────
class _GradientButton extends StatelessWidget {
  final String    label;
  final VoidCallback? onTap;

  const _GradientButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: onTap == null ? 0.5 : 1.0,
        child: Container(
          width: double.infinity, height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [_purple, _violet],
                begin: Alignment.centerLeft, end: Alignment.centerRight),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(
                color: _purple.withOpacity(0.4),
                blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Center(child: Text(label,
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 15))),
        ),
      ),
    );
  }
}
