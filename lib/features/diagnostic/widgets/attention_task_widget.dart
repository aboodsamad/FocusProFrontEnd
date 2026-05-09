import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/diagnostic_question.dart';
import '../../../core/constants/app_colors.dart';

/// Handles all attention-dimension questions.
///
/// Q5 (id=5): Merged reading comprehension + re-read tracker task.
///   Phase 0 — User reads a passage and taps a button each time they re-read.
///   Phase 1 — Passage hidden; user answers 3 comprehension questions.
///   Phase 2 — Combined result displayed, then auto-advances.
///   Scoring combines:
///     Comprehension (Daneman & Carpenter, 1980): 0/3→0pts 1/3→1pt 2/3→3pts 3/3→5pts
///     Re-reads     (Just & Carpenter, 1992):     0→5pts 1-2→3pts 3-4→1pt 5+→0pts
///     Combined 8-10→A(10pts) 5-7→B(6pts) 2-4→C(2pts) 0-1→D(0pts)
///
/// Q7–Q9: Regular option cards (self-reported, ASRS-v1.1 adapted items).
class AttentionTaskWidget extends StatefulWidget {
  final DiagnosticQuestion question;
  final void Function(DiagnosticAnswer answer) onAnswered;

  const AttentionTaskWidget({
    super.key,
    required this.question,
    required this.onAnswered,
  });

  @override
  State<AttentionTaskWidget> createState() => _AttentionTaskWidgetState();
}

class _AttentionTaskWidgetState extends State<AttentionTaskWidget> {
  void _submit(int optionIndex) {
    final letters = ['A', 'B', 'C', 'D'];
    widget.onAnswered(DiagnosticAnswer(
      questionId: widget.question.id,
      selectedOption: letters[optionIndex],
      pointsEarned: widget.question.points[optionIndex],
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.question.id == 5) return _MergedPassageTask(onDone: _submit);
    return _OptionCards(question: widget.question, onSelect: _submit);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Q5 — Merged Passage Task (Reading Comprehension + Re-read Tracker)
// ─────────────────────────────────────────────────────────────────────────────
class _MergedPassageTask extends StatefulWidget {
  final void Function(int optionIndex) onDone;
  const _MergedPassageTask({required this.onDone});

  @override
  State<_MergedPassageTask> createState() => _MergedPassageTaskState();
}

class _MergedPassageTaskState extends State<_MergedPassageTask> {
  int _phase = 0; // 0=reading+rereads, 1=comprehension questions, 2=result
  int _rereads = 0;
  int _questionIndex = 0;
  int _correctAnswers = 0;
  int? _selectedOption;
  bool _answered = false;

  static const String _passage =
      'Every time you receive a notification, your brain needs approximately 23 minutes '
      'to fully return to deep focus — even if you only glanced at your phone for a second. '
      'Frequent task-switching gradually weakens the prefrontal cortex\'s ability to sustain '
      'long periods of concentration. Psychologist Mihaly Csikszentmihalyi described '
      'peak, distraction-free concentration as "flow" — a mental state in which productivity '
      'and creativity surge dramatically. Reaching flow requires roughly 15 to 25 minutes '
      'of uninterrupted work. Research by Baddeley (2003) on working memory shows that the '
      'brain\'s phonological loop — the system that temporarily holds verbal information — '
      'has a limited capacity that becomes strained under divided attention, causing readers '
      'to lose their place and re-read passages.';

  static const List<Map<String, dynamic>> _questions = [
    {
      'question': 'How long does the brain typically need to return to deep focus after a notification?',
      'options': ['About 5 minutes', 'About 23 minutes', 'About 45 minutes', 'Over an hour'],
      'correctIndex': 1,
    },
    {
      'question': 'What does Csikszentmihalyi\'s concept of "flow" describe?',
      'options': [
        'A speed-reading method',
        'A breathing technique',
        'A peak state of effortless concentration',
        'A form of multitasking',
      ],
      'correctIndex': 2,
    },
    {
      'question': 'According to Baddeley\'s research, what happens to the phonological loop under divided attention?',
      'options': [
        'It strengthens over time',
        'It helps retain long-term memory',
        'It has unlimited verbal capacity',
        'Its capacity becomes strained',
      ],
      'correctIndex': 3,
    },
  ];

  int _toOptionIndex() {
    final comprehensionPts = _correctAnswers == 3
        ? 5
        : _correctAnswers == 2
            ? 3
            : _correctAnswers == 1
                ? 1
                : 0;
    final rereadPts = _rereads == 0
        ? 5
        : _rereads <= 2
            ? 3
            : _rereads <= 4
                ? 1
                : 0;
    final combined = comprehensionPts + rereadPts;
    if (combined >= 8) return 0; // A — 10 pts
    if (combined >= 5) return 1; // B — 6 pts
    if (combined >= 2) return 2; // C — 2 pts
    return 3;                    // D — 0 pts
  }

  void _onSelectOption(int idx) {
    if (_answered) return;
    HapticFeedback.lightImpact();
    final isCorrect = idx == _questions[_questionIndex]['correctIndex'] as int;
    setState(() {
      _selectedOption = idx;
      _answered = true;
      if (isCorrect) _correctAnswers++;
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      if (_questionIndex < _questions.length - 1) {
        setState(() {
          _questionIndex++;
          _selectedOption = null;
          _answered = false;
        });
      } else {
        setState(() => _phase = 2);
        Future.delayed(const Duration(milliseconds: 1400), () {
          if (mounted) widget.onDone(_toOptionIndex());
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == 0) return _buildReadingPhase();
    if (_phase == 1) return _buildQuestionPhase();
    return _buildResultPhase();
  }

  // ── Phase 0: Reading + Re-read counter ──────────────────────────────────
  Widget _buildReadingPhase() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header badges
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primaryA, AppColors.primaryB]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.science_rounded, color: Colors.white, size: 13),
                  SizedBox(width: 5),
                  Text('Reading & Memory Assessment',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, color: Colors.orange, size: 13),
                  SizedBox(width: 5),
                  Text('Track re-reads', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'Read carefully — then answer 3 questions',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        Text(
          'Tap the re-read button each time you go back over a sentence.',
          style: TextStyle(color: Colors.grey[500], fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 18),

        // Passage card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryA.withOpacity(0.10),
                AppColors.primaryA.withOpacity(0.03),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primaryA.withOpacity(0.22), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primaryA.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.auto_stories_rounded, color: AppColors.primaryA, size: 17),
                  ),
                  const SizedBox(width: 10),
                  const Text('Passage',
                      style: TextStyle(color: AppColors.primaryA, fontWeight: FontWeight.bold, fontSize: 13)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('3 questions follow',
                        style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(_passage,
                  style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.75)),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Re-read counter button
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _rereads++);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.withOpacity(0.15), Colors.orange.withOpacity(0.06)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.withOpacity(0.4), width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.refresh_rounded, color: Colors.orange, size: 22),
                const SizedBox(width: 10),
                const Text('I re-read something',
                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text('$_rereads',
                      style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 17)),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Done reading → go to comprehension questions
        GestureDetector(
          onTap: () => setState(() => _phase = 1),
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primaryA, AppColors.primaryB]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: AppColors.primaryA.withOpacity(0.4), blurRadius: 18, offset: const Offset(0, 6)),
              ],
            ),
            child: const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("I've read it — show questions",
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  SizedBox(width: 10),
                  Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Phase 1: Comprehension questions ────────────────────────────────────
  Widget _buildQuestionPhase() {
    final q = _questions[_questionIndex];
    final opts = q['options'] as List<String>;
    final correctIdx = q['correctIndex'] as int;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sub-progress bar
        Row(
          children: List.generate(3, (i) {
            Color c;
            if (i < _questionIndex) {
              c = const Color(0xFF34D399);
            } else if (i == _questionIndex) {
              c = AppColors.primaryA;
            } else {
              c = Colors.grey[800]!;
            }
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                height: 4,
                decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text('Question ${_questionIndex + 1} of 3  —  passage is now hidden',
            style: TextStyle(color: Colors.grey[600], fontSize: 11)),
        const SizedBox(height: 20),

        // Question card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryA.withOpacity(0.12), AppColors.primaryA.withOpacity(0.04)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.primaryA.withOpacity(0.25), width: 1.5),
          ),
          child: Text(
            q['question'] as String,
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, height: 1.4),
          ),
        ),
        const SizedBox(height: 16),

        // Answer options
        ...List.generate(4, (i) {
          final isSelected = _selectedOption == i;
          final isCorrect = _answered && i == correctIdx;
          final isWrong = _answered && isSelected && i != correctIdx;

          Color borderColor;
          Color bgColor;
          Color textColor;
          Widget? trailingIcon;

          if (isCorrect && _answered) {
            borderColor = const Color(0xFF34D399);
            bgColor = const Color(0xFF34D399).withOpacity(0.12);
            textColor = Colors.white;
            trailingIcon = const Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 20);
          } else if (isWrong) {
            borderColor = Colors.redAccent;
            bgColor = Colors.redAccent.withOpacity(0.10);
            textColor = Colors.white;
            trailingIcon = const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 20);
          } else if (isSelected) {
            borderColor = AppColors.primaryA;
            bgColor = AppColors.primaryA.withOpacity(0.12);
            textColor = Colors.white;
            trailingIcon = null;
          } else {
            borderColor = Colors.white.withOpacity(0.1);
            bgColor = Colors.white.withOpacity(0.04);
            textColor = Colors.grey[300]!;
            trailingIcon = null;
          }

          return GestureDetector(
            onTap: () => _onSelectOption(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor, width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected || (isCorrect && _answered)
                          ? borderColor.withOpacity(0.25)
                          : Colors.white.withOpacity(0.06),
                      border: Border.all(color: borderColor.withOpacity(0.5)),
                    ),
                    child: Center(
                      child: Text(['A', 'B', 'C', 'D'][i],
                          style: TextStyle(
                              color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(opts[i],
                        style: TextStyle(color: textColor, fontSize: 14, height: 1.35)),
                  ),
                  if (trailingIcon != null) ...[
                    const SizedBox(width: 8),
                    trailingIcon,
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── Phase 2: Combined result ─────────────────────────────────────────────
  Widget _buildResultPhase() {
    final idx = _toOptionIndex();
    final labels = ['Excellent Focus Capacity', 'Good Focus Capacity', 'Fair Focus Capacity', 'Low Focus Capacity'];
    final colors = [const Color(0xFF34D399), AppColors.primaryA, Colors.orange, Colors.redAccent];
    final color = colors[idx];
    final label = labels[idx];

    return Center(
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 110, height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              boxShadow: [BoxShadow(color: color.withOpacity(0.45), blurRadius: 30, spreadRadius: 4)],
            ),
            child: Center(
              child: Text('$_correctAnswers/3',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 14),
          Text(label, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.refresh_rounded, color: Colors.grey[500], size: 14),
              const SizedBox(width: 5),
              Text('$_rereads re-read${_rereads == 1 ? '' : 's'}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Calculating your attention score…',
              style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Q7–Q9 — Regular Option Cards (auto-advance on tap)
// ─────────────────────────────────────────────────────────────────────────────
class _OptionCards extends StatefulWidget {
  final DiagnosticQuestion question;
  final void Function(int optionIndex) onSelect;
  const _OptionCards({required this.question, required this.onSelect});

  @override
  State<_OptionCards> createState() => _OptionCardsState();
}

class _OptionCardsState extends State<_OptionCards> {
  int? _selected;
  bool _advancing = false;

  void _onTap(int i) {
    if (_advancing) return;
    HapticFeedback.lightImpact();
    setState(() {
      _selected = i;
      _advancing = true;
    });
    Future.delayed(const Duration(milliseconds: 380), () {
      if (mounted) widget.onSelect(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(4, (i) {
        final isSelected = _selected == i;
        final label = ['A', 'B', 'C', 'D'][i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () => _onTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [AppColors.primaryA, AppColors.primaryB],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                    : LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.07),
                          Colors.white.withOpacity(0.03),
                        ],
                      ),
                border: Border.all(
                  color: isSelected ? AppColors.primaryA : Colors.white.withOpacity(0.1),
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: AppColors.primaryA.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 6))]
                    : null,
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? Colors.white.withOpacity(0.25) : Colors.white.withOpacity(0.06),
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[400],
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.question.options[i],
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[300],
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedOpacity(
                    opacity: isSelected ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
