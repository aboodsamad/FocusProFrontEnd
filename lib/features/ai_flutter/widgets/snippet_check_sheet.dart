import 'package:flutter/material.dart';
import '../models/ai_question_model.dart';
import '../services/ai_service.dart';

const _bg     = Color(0xFF080B14);
const _cardBg = Color(0xFF0F1524);
const _purple = Color(0xFF8B5CF6);
const _violet = Color(0xFFA78BFA);
const _green  = Color(0xFF34D399);
const _red    = Color(0xFFEF4444);

Future<bool> showSnippetCheckSheet(
  BuildContext context, {
  required int snippetId,
  required String token,
  void Function(double gained)? onScoreGained,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _SnippetCheckSheet(
      snippetId: snippetId,
      token: token,
      onScoreGained: onScoreGained,
    ),
  );
  return result ?? false;
}

class _SnippetCheckSheet extends StatefulWidget {
  final int snippetId;
  final String token;
  final void Function(double gained)? onScoreGained;
  const _SnippetCheckSheet({
    required this.snippetId,
    required this.token,
    this.onScoreGained,
  });

  @override
  State<_SnippetCheckSheet> createState() => _SnippetCheckSheetState();
}

class _SnippetCheckSheetState extends State<_SnippetCheckSheet>
    with SingleTickerProviderStateMixin {

  List<AiQuestionModel> _questions = [];
  final Map<int, String> _answers  = {};
  int     _currentIndex            = 0;
  bool    _loading                 = true;
  bool    _submitting              = false;
  String? _error;
  SnippetCheckResult? _result;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _loadQuestions();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    setState(() { _loading = true; _error = null; });
    final q = await AiService.getSnippetQuestions(widget.snippetId, widget.token);
    if (!mounted) return;
    if (q.isEmpty) {
      setState(() { _loading = false; _error = 'Could not load questions. Try again.'; });
      return;
    }
    setState(() { _questions = q; _loading = false; });
    _fadeCtrl.forward();
  }

  Future<void> _submit() async {
    if (_answers.length < _questions.length) return;
    setState(() => _submitting = true);
    final result = await AiService.submitSnippetAnswers(widget.snippetId, _answers, widget.token);
    if (!mounted) return;
    setState(() { _submitting = false; _result = result; });
    if (result != null && result.passed && result.focusScoreGained > 0) {
      widget.onScoreGained?.call(result.focusScoreGained);
    }
  }

  void _nextQuestion() {
    _fadeCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() => _currentIndex++);
      _fadeCtrl.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(children: [
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Expanded(child: _buildBody()),
      ]),
    );
  }

  Widget _buildBody() {
    if (_loading)        return _buildLoading();
    if (_error != null)  return _buildError();
    if (_result != null) return _buildResult();
    return _buildQuestions();
  }

  Widget _buildLoading() {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
              colors: [_purple, _violet],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          boxShadow: [BoxShadow(
              color: _purple.withOpacity(0.4), blurRadius: 24, spreadRadius: 4)],
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
        ),
      ),
      const SizedBox(height: 24),
      const Text('AI is preparing your questions…',
          style: TextStyle(color: Colors.white70, fontSize: 15)),
      const SizedBox(height: 8),
      const Text('This may take a few seconds',
          style: TextStyle(color: Colors.white38, fontSize: 13)),
    ]);
  }

  Widget _buildError() {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, color: _red, size: 52),
      const SizedBox(height: 16),
      Text(_error!, style: const TextStyle(color: Colors.white70, fontSize: 15)),
      const SizedBox(height: 24),
      _GradientButton(label: 'Retry', onTap: _loadQuestions),
      const SizedBox(height: 12),
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Skip for now', style: TextStyle(color: Colors.white38)),
      ),
    ]);
  }

  Widget _buildQuestions() {
    final q      = _questions[_currentIndex];
    final isLast = _currentIndex == _questions.length - 1;
    final chosen = _answers[q.questionId];

    return FadeTransition(
      opacity: _fadeAnim,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_purple, _violet]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(children: [
                Icon(Icons.psychology_outlined, color: Colors.white, size: 15),
                SizedBox(width: 6),
                Text('Quick Check', style: TextStyle(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
            const Spacer(),
            Text('${_currentIndex + 1} / ${_questions.length}',
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ]),

          const SizedBox(height: 6),

          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentIndex + 1) / _questions.length,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(_purple),
              minHeight: 4,
            ),
          ),

          const SizedBox(height: 24),

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
                    color: Colors.white, fontSize: 16, height: 1.5,
                    fontWeight: FontWeight.w500)),
          ),

          const SizedBox(height: 20),

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
                  ? (_submitting ? 'Submitting…' : 'Submit Answers')
                  : 'Next Question',
              onTap: _submitting ? null : (isLast ? _submit : _nextQuestion),
            ),
        ]),
      ),
    );
  }

  Widget _buildResult() {
    final r     = _result!;
    final color = r.passed ? _green : _red;
    final emoji = r.passed ? '🎉' : '📖';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(children: [
        Container(
          width: 110, height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: r.passed ? [_purple, _violet] : [_red, const Color(0xFFB91C1C)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            boxShadow: [BoxShadow(
                color: color.withOpacity(0.4), blurRadius: 28, spreadRadius: 4)],
          ),
          child: Center(child: Text(
            '${r.correctCount}/${r.totalQuestions}',
            style: const TextStyle(color: Colors.white, fontSize: 28,
                fontWeight: FontWeight.bold),
          )),
        ),

        const SizedBox(height: 20),

        Text('$emoji ${r.passed ? 'Passed!' : 'Not quite'}',
            style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),

        const SizedBox(height: 8),

        Text(r.message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),

        if (r.passed && r.focusScoreGained > 0) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: _green.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _green.withOpacity(0.4)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.bolt, color: _green, size: 18),
              const SizedBox(width: 6),
              Text('+${r.focusScoreGained.toStringAsFixed(1)} focus points',
                  style: const TextStyle(
                      color: _green, fontWeight: FontWeight.w600, fontSize: 14)),
            ]),
          ),
        ],

        const SizedBox(height: 28),

        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Results', style: TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 12),

        for (int i = 0; i < r.results.length; i++)
          _ResultRow(index: i + 1, result: r.results[i], question: _questions[i]),

        const SizedBox(height: 28),

        _GradientButton(
          label: r.passed ? 'Continue Reading' : 'Review & Try Again',
          onTap: () => Navigator.pop(context, r.passed),
        ),

        if (!r.passed) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Skip for now',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
          ),
        ],
      ]),
    );
  }
}

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
              color: isSelected ? Colors.transparent : Colors.white12,
              width: 1.5),
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

class _ResultRow extends StatelessWidget {
  final int             index;
  final AiAnswerResult  result;
  final AiQuestionModel question;

  const _ResultRow({required this.index, required this.result, required this.question});

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
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [_purple, _violet],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(
                color: _purple.withOpacity(0.4), blurRadius: 16,
                offset: const Offset(0, 6))],
          ),
          child: Center(child: Text(label,
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 15))),
        ),
      ),
    );
  }
}