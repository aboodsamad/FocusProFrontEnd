import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/diagnostic_question.dart';
import '../../../core/constants/app_colors.dart';

/// Used for attention dimension questions.
///
/// Q5 (id=5): Reading Comprehension Task — user reads a passage, then answers
///             comprehension questions to behaviorally measure sustained attention.
///             Based on Prose Recall paradigm (Daneman & Carpenter, 1980) and
///             Gloria Mark's attention research (Mark et al., CHI 2008).
/// Q6 (id=6): Re-read tracker — show text, user taps re-read, we count taps.
///             Measures working memory load during reading (Just & Carpenter, 1992).
/// Q7–Q9:     Regular option cards (self-reported, ASRS-v1.1 adapted items).
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
    if (widget.question.id == 5) return _ReadingComprehensionTask(onDone: _submit);
    if (widget.question.id == 6) return _RereadTrackerTask(onDone: _submit);
    return _OptionCards(question: widget.question, onSelect: _submit);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Q5 — Reading Comprehension Task
// Scientific basis: Prose Recall paradigm (Daneman & Carpenter, 1980,
// Cognitive Psychology); attention measurement via reading comprehension
// as used in cognitive assessments (Gloria Mark et al., CHI 2008).
// The user reads a passage, then answers comprehension questions —
// a behaviorally validated measure of sustained reading attention and
// working memory capacity, far more objective than self-report.
// ─────────────────────────────────────────────────────────────────────────────
class _ReadingComprehensionTask extends StatefulWidget {
  final void Function(int optionIndex) onDone;
  const _ReadingComprehensionTask({required this.onDone});

  @override
  State<_ReadingComprehensionTask> createState() =>
      _ReadingComprehensionTaskState();
}

class _ReadingComprehensionTaskState
    extends State<_ReadingComprehensionTask> {
  // 0 = reading phase, 1 = question phase, 2 = result phase
  int _phase = 0;
  int _questionIndex = 0;
  int _correctAnswers = 0;
  int? _selectedOption;
  bool _answered = false;

  static const String _passage =
      'Every time you get a notification, your brain needs about 23 minutes '
      'to fully get back into deep focus — even if you only glance at your '
      'phone for a second. The more you switch between tasks, the harder it '
      'becomes for your brain to stay focused for long periods of time.';

  // Each item: { question, options [A,B,C,D], correctIndex }
  static const List<Map<String, dynamic>> _questions = [
    {
      'question': 'Which brain region governs sustained focused attention?',
      'options': [
        'The hippocampus',
        'The prefrontal cortex',
        'The amygdala',
        'The cerebellum',
      ],
      'correctIndex': 1,
    },
    {
      'question':
          'According to Gloria Mark\'s research, how long does it take to regain deep focus after an interruption?',
      'options': [
        'About 5 minutes',
        'About 10 minutes',
        'About 23 minutes',
        'About 45 minutes',
      ],
      'correctIndex': 2,
    },
    {
      'question': 'What long-term effect does chronic multitasking have on the brain?',
      'options': [
        'It strengthens neural pathways for multitasking',
        'It has no measurable structural effect',
        'It reduces working memory capacity',
        'It only affects emotional regulation',
      ],
      'correctIndex': 2,
    },
  ];

  int _toOptionIndex() {
    if (_correctAnswers == 3) return 0; // A — 5 pts
    if (_correctAnswers == 2) return 1; // B — 3 pts
    if (_correctAnswers == 1) return 2; // C — 1 pt
    return 3;                           // D — 0 pts
  }

  void _onSelectOption(int idx) {
    if (_answered) return;
    HapticFeedback.lightImpact();
    final isCorrect =
        idx == _questions[_questionIndex]['correctIndex'] as int;
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
        Future.delayed(const Duration(milliseconds: 1200), () {
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

  // ── Phase 0: Reading ──────────────────────────────────────────────────────
  Widget _buildReadingPhase() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Science badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppColors.primaryA, AppColors.primaryB]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.science_rounded, color: Colors.white, size: 13),
              SizedBox(width: 6),
              Text('Prose Recall Assessment',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Read carefully — questions follow',
          style: TextStyle(
              color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'This measures how well your attention holds during reading.',
          style: TextStyle(color: Colors.grey[500], fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 20),
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
            border: Border.all(
                color: AppColors.primaryA.withOpacity(0.22), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primaryA.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.auto_stories_rounded,
                        color: AppColors.primaryA, size: 17),
                  ),
                  const SizedBox(width: 10),
                  const Text('Passage',
                      style: TextStyle(
                          color: AppColors.primaryA,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('3 questions ahead',
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _passage,
                style: const TextStyle(
                    color: Colors.white, fontSize: 15, height: 1.7),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // CTA
        GestureDetector(
          onTap: () => setState(() => _phase = 1),
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.primaryA, AppColors.primaryB]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryA.withOpacity(0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("I've read it — show questions",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  SizedBox(width: 10),
                  Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Phase 1: Questions ────────────────────────────────────────────────────
  Widget _buildQuestionPhase() {
    final q = _questions[_questionIndex];
    final opts = q['options'] as List<String>;
    final correctIdx = q['correctIndex'] as int;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress indicator
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
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text('Question ${_questionIndex + 1} of 3 — passage is now hidden',
            style: TextStyle(color: Colors.grey[600], fontSize: 11)),
        const SizedBox(height: 20),
        // Question card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryA.withOpacity(0.12),
                AppColors.primaryA.withOpacity(0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: AppColors.primaryA.withOpacity(0.25), width: 1.5),
          ),
          child: Text(
            q['question'] as String,
            style: const TextStyle(
                color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, height: 1.4),
          ),
        ),
        const SizedBox(height: 16),
        // Options
        ...List.generate(4, (i) {
          bool isSelected = _selectedOption == i;
          bool isCorrect  = _answered && i == correctIdx;
          bool isWrong    = _answered && isSelected && i != correctIdx;

          Color borderColor;
          Color bgColor;
          Color textColor;
          Widget? trailingIcon;

          if (isCorrect && _answered) {
            borderColor = const Color(0xFF34D399);
            bgColor     = const Color(0xFF34D399).withOpacity(0.12);
            textColor   = Colors.white;
            trailingIcon = const Icon(Icons.check_circle_rounded,
                color: Color(0xFF34D399), size: 20);
          } else if (isWrong) {
            borderColor = Colors.redAccent;
            bgColor     = Colors.redAccent.withOpacity(0.10);
            textColor   = Colors.white;
            trailingIcon = const Icon(Icons.cancel_rounded,
                color: Colors.redAccent, size: 20);
          } else if (isSelected) {
            borderColor = AppColors.primaryA;
            bgColor     = AppColors.primaryA.withOpacity(0.12);
            textColor   = Colors.white;
            trailingIcon = null;
          } else {
            borderColor = Colors.white.withOpacity(0.1);
            bgColor     = Colors.white.withOpacity(0.04);
            textColor   = Colors.grey[300]!;
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
                    width: 30,
                    height: 30,
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
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(opts[i],
                        style: TextStyle(
                            color: textColor, fontSize: 14, height: 1.35)),
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

  // ── Phase 2: Result ───────────────────────────────────────────────────────
  Widget _buildResultPhase() {
    final labels = ['Excellent recall', 'Good recall', 'Fair recall', 'Low recall'];
    final colors = [
      const Color(0xFF34D399),
      AppColors.primaryA,
      Colors.orange,
      Colors.redAccent,
    ];
    final idx    = _toOptionIndex();
    final color  = colors[idx];
    final label  = labels[idx];

    return Center(
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.45),
                    blurRadius: 30,
                    spreadRadius: 4),
              ],
            ),
            child: Center(
              child: Text('$_correctAnswers/3',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 18),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Calculating your attention score…',
              style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Q6 — Re-read Tracker Task
// ─────────────────────────────────────────────────────────────────────────────
class _RereadTrackerTask extends StatefulWidget {
  final void Function(int optionIndex) onDone;
  const _RereadTrackerTask({required this.onDone});

  @override
  State<_RereadTrackerTask> createState() => _RereadTrackerTaskState();
}

class _RereadTrackerTaskState extends State<_RereadTrackerTask> {
  int _rereads = 0;

  static const String _passage =
      'Psychologist Mihaly Csikszentmihalyi identified a mental state called '
      '"flow" — a peak condition of effortless, deep concentration during '
      'which productivity and creativity surge. Entering flow requires '
      'approximately 15 to 25 minutes of uninterrupted focus. Studies on '
      'working memory (Baddeley, 2003) confirm that the phonological loop — '
      'the brain system responsible for holding verbal information — has a '
      'limited capacity that becomes strained when reading without full '
      'attention, causing readers to lose track and re-read lines.';

  int _toOptionIndex() {
    if (_rereads == 0) return 0;
    if (_rereads <= 2) return 1;
    if (_rereads <= 4) return 2;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Passage card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.07),
                Colors.white.withOpacity(0.03),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.primaryA.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.auto_stories_rounded,
                        color: AppColors.primaryA, size: 16),
                  ),
                  const SizedBox(width: 10),
                  const Text('Working Memory Task — read carefully',
                      style: TextStyle(
                          color: AppColors.primaryA,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _passage,
                style: TextStyle(
                    color: Colors.grey[300], fontSize: 14, height: 1.65),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        Text(
          'Tap the button below every time you re-read a sentence. '
          'Re-reading frequency indicates working memory load '
          '(Just & Carpenter, 1992).',
          style:
              TextStyle(color: Colors.grey[400], fontSize: 13, height: 1.4),
        ),

        const SizedBox(height: 16),

        // Re-read counter
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _rereads++);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.orange.withOpacity(0.15),
                  Colors.orange.withOpacity(0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: Colors.orange.withOpacity(0.4), width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.refresh_rounded,
                    color: Colors.orange, size: 22),
                const SizedBox(width: 10),
                const Text('I re-read something',
                    style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text('$_rereads',
                      style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 17)),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Done reading
        SizedBox(
          width: double.infinity,
          height: 56,
          child: GestureDetector(
            onTap: () => widget.onDone(_toOptionIndex()),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.primaryA, AppColors.primaryB]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryA.withOpacity(0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Done Reading',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded,
                        color: Colors.white, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
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
                  color: isSelected
                      ? AppColors.primaryA
                      : Colors.white.withOpacity(0.1),
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primaryA.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        )
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? Colors.white.withOpacity(0.25)
                          : Colors.white.withOpacity(0.06),
                      border: Border.all(
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withOpacity(0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          color:
                              isSelected ? Colors.white : Colors.grey[400],
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
                        color:
                            isSelected ? Colors.white : Colors.grey[300],
                        fontSize: 15,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedOpacity(
                    opacity: isSelected ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 16),
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
