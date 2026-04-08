import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/diagnostic_question.dart';
import '../../../core/constants/app_colors.dart';

/// Used for attention dimension questions.
///
/// Q5 (id=5): Focus timer — user taps when mind wanders, we measure how long.
/// Q6 (id=6): Re-read tracker — show text, user taps re-read, we count taps.
/// Q7–Q9:     Regular option cards (self-reported, no task needed).
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
    if (widget.question.id == 5) return _FocusTimerTask(onDone: _submit);
    if (widget.question.id == 6) return _RereadTrackerTask(onDone: _submit);
    return _OptionCards(question: widget.question, onSelect: _submit);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Q5 — Focus Timer Task
// ─────────────────────────────────────────────────────────────────────────────
class _FocusTimerTask extends StatefulWidget {
  final void Function(int optionIndex) onDone;
  const _FocusTimerTask({required this.onDone});

  @override
  State<_FocusTimerTask> createState() => _FocusTimerTaskState();
}

class _FocusTimerTaskState extends State<_FocusTimerTask> {
  Timer? _timer;
  int _seconds = 0;
  bool _running = false;
  bool _done = false;

  void _start() {
    setState(() => _running = true);
    _timer =
        Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  void _stop() {
    _timer?.cancel();
    setState(() {
      _running = false;
      _done = true;
    });
  }

  int _toOptionIndex() {
    final minutes = _seconds / 60;
    if (minutes > 45) return 0;
    if (minutes >= 20) return 1;
    if (minutes >= 10) return 2;
    return 3;
  }

  String get _formatted {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Instruction card
        Container(
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primaryA.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.psychology_outlined,
                    color: AppColors.primaryA, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Focus Timer Task',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Text(
                      _running
                          ? 'Stay focused. Tap STOP the moment your mind wanders.'
                          : _done
                              ? 'Great — your result has been recorded.'
                              : 'Tap START, stay focused. Tap STOP when your mind drifts.',
                      style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 13,
                          height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 36),

        // Big circular timer
        Container(
          width: 168,
          height: 168,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.04),
            border: Border.all(
              color: _running
                  ? AppColors.primaryA.withOpacity(0.55)
                  : Colors.grey[800]!,
              width: 2,
            ),
            boxShadow: _running
                ? [
                    BoxShadow(
                      color: AppColors.primaryA.withOpacity(0.22),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              _formatted,
              style: TextStyle(
                fontSize: 46,
                fontWeight: FontWeight.bold,
                color:
                    _running ? AppColors.primaryA : Colors.grey[600],
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),

        const SizedBox(height: 36),

        if (!_done) ...[
          SizedBox(
            width: double.infinity,
            height: 56,
            child: _running
                ? _gradientButton(
                    colors: const [Colors.redAccent, Color(0xFFE53935)],
                    glowColor: Colors.redAccent,
                    onTap: _stop,
                    icon: Icons.stop_rounded,
                    label: 'My mind just wandered',
                  )
                : _gradientButton(
                    colors: const [AppColors.primaryA, AppColors.primaryB],
                    glowColor: AppColors.primaryA,
                    onTap: _start,
                    icon: Icons.play_arrow_rounded,
                    label: 'Start Timer',
                  ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF34D399).withOpacity(0.15),
                  const Color(0xFF34D399).withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFF34D399).withOpacity(0.4),
                  width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline,
                    color: Color(0xFF34D399), size: 20),
                const SizedBox(width: 10),
                Text('You stayed focused for $_formatted',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: _gradientButton(
              colors: const [AppColors.primaryA, AppColors.primaryB],
              glowColor: AppColors.primaryA,
              onTap: () => widget.onDone(_toOptionIndex()),
              icon: Icons.arrow_forward_rounded,
              label: 'Next',
            ),
          ),
        ],
      ],
    );
  }

  Widget _gradientButton({
    required List<Color> colors,
    required Color glowColor,
    required VoidCallback onTap,
    required IconData icon,
    required String label,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: glowColor.withOpacity(0.4),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
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
      'The human brain is remarkably adaptable, but it requires consistent '
      'stimulation to maintain peak cognitive performance. Research has shown '
      'that regular reading, problem-solving, and focused work sessions '
      'strengthen neural pathways associated with sustained attention. '
      'In contrast, fragmented screen time — characterized by rapid switching '
      'between short content — has been linked to reduced working memory '
      'capacity and lower ability to engage in deep, focused thinking.';

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
                  const Text('Read this passage carefully',
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
          'Tap the button below every time you re-read a sentence.',
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
