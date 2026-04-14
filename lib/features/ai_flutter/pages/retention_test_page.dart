import 'package:capstone_front_end/core/services/auth_service.dart';
import 'package:capstone_front_end/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import '../models/ai_question_model.dart';
import '../services/ai_service.dart';

/// Full-page retention test — Deep Focus design.
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
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withOpacity(0.9),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: AppColors.onSurface,
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.spa_outlined, color: AppColors.primaryContainer, size: 20),
            const SizedBox(width: 8),
            Text(
              'FocusPro',
              style: TextStyle(
                color: AppColors.primaryContainer,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.close, color: AppColors.onSurfaceVariant),
            onPressed: () => Navigator.pop(context),
          ),
        ],
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
          color: AppColors.primaryContainer,
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: AppColors.primaryFixed, strokeWidth: 2.5),
        ),
      ),
      const SizedBox(height: 28),
      Text(
        'AI is building your retention test…',
        style: TextStyle(color: AppColors.onSurface, fontSize: 15,
            fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 8),
      Text(
        'Pulling from your past reading',
        style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
      ),
    ]));
  }

  // ── Error ─────────────────────────────────────────────────────────────────
  Widget _buildError() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.menu_book_outlined, color: AppColors.secondary, size: 64),
        const SizedBox(height: 20),
        Text(_error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.onSurfaceVariant,
                fontSize: 15, height: 1.6)),
        const SizedBox(height: 32),
        _PrimaryButton(label: 'Go Back', onTap: () => Navigator.pop(context)),
      ]),
    ));
  }

  // ── Questions ─────────────────────────────────────────────────────────────
  Widget _buildQuestions() {
    final q      = _questions[_currentIndex];
    final isLast = _currentIndex == _questions.length - 1;
    final chosen = _answers[q.questionId];

    return Column(children: [
      Expanded(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Progress header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'KNOWLEDGE CHECK',
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    'Question ${_currentIndex + 1} of ${_questions.length}',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentIndex + 1) / _questions.length,
                  backgroundColor: AppColors.surfaceContainer,
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  minHeight: 6,
                ),
              ),

              const SizedBox(height: 28),

              // Question text
              Text(q.questionText,
                  style: const TextStyle(
                      color: AppColors.primary, fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.3, letterSpacing: -0.5)),

              const SizedBox(height: 24),

              // Options
              for (final letter in ['A', 'B', 'C', 'D'])
                _OptionTile(
                  letter: letter,
                  text: q.optionText(letter),
                  isSelected: chosen == letter,
                  onTap: () => setState(() => _answers[q.questionId] = letter),
                ),
            ]),
          ),
        ),
      ),

      // Bottom action bar
      if (chosen != null)
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: _PrimaryButton(
            label: isLast
                ? (_submitting ? 'Submitting…' : 'Submit Test')
                : 'Next Question',
            trailing: isLast ? null : Icons.arrow_forward,
            onTap: _submitting ? null : (isLast ? _submit : _nextQuestion),
          ),
        ),
    ]);
  }

  // ── Result ────────────────────────────────────────────────────────────────
  Widget _buildResult() {
    final r      = _result!;
    final gained = r.scoreDelta > 0;
    final lost   = r.scoreDelta < 0;
    final pct    = r.totalQuestions > 0
        ? (r.correctCount / r.totalQuestions * 100).round()
        : 0;

    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(children: [

            // Result card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(children: [

                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.verified, color: AppColors.onSecondaryContainer, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      gained ? 'ASSESSMENT PASSED' : lost ? 'NEEDS REVIEW' : 'ASSESSMENT COMPLETE',
                      style: TextStyle(
                        color: AppColors.onSecondaryContainer,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 20),

                // Score percentage
                Text(
                  '$pct%',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2,
                    height: 1,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  gained ? 'Strong Retention' : lost ? 'Needs Review' : 'Decent Retention',
                  style: const TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 8),

                Text(r.message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.onSurfaceVariant, fontSize: 14, height: 1.5)),

                const SizedBox(height: 20),

                // Stats row
                Row(children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('SCORE DELTA',
                            style: TextStyle(
                              color: AppColors.onSurfaceVariant.withOpacity(0.7),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            )),
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(
                            gained ? Icons.trending_up : lost ? Icons.trending_down : Icons.trending_flat,
                            color: gained ? AppColors.secondary : lost ? AppColors.error : AppColors.onSurfaceVariant,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            gained ? '+${r.scoreDelta.toStringAsFixed(1)}' : r.scoreDelta.toStringAsFixed(1),
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ]),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('ACCURACY',
                            style: TextStyle(
                              color: AppColors.onSurfaceVariant.withOpacity(0.7),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            )),
                        const SizedBox(height: 4),
                        Text(
                          '${r.correctCount}/${r.totalQuestions}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ]),
                    ),
                  ),
                ]),
              ]),
            ),

            const SizedBox(height: 24),

            // Breakdown
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Question Breakdown',
                  style: TextStyle(color: AppColors.onSurface,
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 12),

            for (int i = 0; i < r.results.length; i++)
              _ResultRow(index: i + 1, result: r.results[i], question: _questions[i]),
          ]),
        ),
      ),

      Container(
        color: AppColors.surface,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: _PrimaryButton(label: 'Back to App', onTap: () => Navigator.pop(context)),
      ),
    ]);
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
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected ? Colors.transparent : AppColors.surfaceContainerLow,
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(
              'Option $letter',
              style: TextStyle(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.6)
                    : AppColors.onSurfaceVariant.withOpacity(0.6),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: AppColors.primary, size: 20),
          ]),
          const SizedBox(height: 6),
          Text(text,
              style: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.onSurface,
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  height: 1.4)),
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
    final color   = correct ? AppColors.secondary : AppColors.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(correct ? Icons.check_circle : Icons.cancel, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('Q$index: ${question.questionText}',
              style: TextStyle(color: AppColors.onSurface, fontSize: 13),
              maxLines: 2, overflow: TextOverflow.ellipsis)),
        ]),
        if (!correct) ...[
          const SizedBox(height: 8),
          Text('Your answer:    ${result.chosenAnswer} — ${question.optionText(result.chosenAnswer)}',
              style: TextStyle(color: AppColors.error, fontSize: 12)),
          Text('Correct answer: ${result.correctAnswer} — ${question.optionText(result.correctAnswer)}',
              style: TextStyle(color: AppColors.secondary, fontSize: 12)),
        ],
      ]),
    );
  }
}

// ── Primary button ────────────────────────────────────────────────────────────
class _PrimaryButton extends StatelessWidget {
  final String    label;
  final IconData? trailing;
  final VoidCallback? onTap;

  const _PrimaryButton({required this.label, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: onTap == null ? 0.5 : 1.0,
        child: Container(
          width: double.infinity, height: 56,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              Icon(trailing, color: AppColors.onPrimary, size: 20),
            ],
          ]),
        ),
      ),
    );
  }
}
