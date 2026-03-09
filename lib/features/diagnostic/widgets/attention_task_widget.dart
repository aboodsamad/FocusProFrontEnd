import 'dart:async';
import 'package:flutter/material.dart';
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
      questionId:     widget.question.id,
      selectedOption: letters[optionIndex],
      pointsEarned:   widget.question.points[optionIndex],
    ));
  }

  @override
  Widget build(BuildContext context) {
    // Q5: focus timer task
    if (widget.question.id == 5) {
      return _FocusTimerTask(onDone: _submit);
    }
    // Q6: re-read tracker task
    if (widget.question.id == 6) {
      return _RereadTrackerTask(onDone: _submit);
    }
    // Q7–Q9: regular option cards
    return _OptionCards(question: widget.question, onSelect: _submit);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Q5 — Focus Timer Task
// User taps START, tries to stay focused, taps STOP when mind wanders.
// Time → mapped to A/B/C/D:  >45min=A  20-45=B  10-20=C  <10=D
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
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  void _stop() {
    _timer?.cancel();
    setState(() { _running = false; _done = true; });
  }

  int _toOptionIndex() {
    final minutes = _seconds / 60;
    if (minutes > 45)       return 0; // A — +5
    if (minutes >= 20)      return 1; // B — +3
    if (minutes >= 10)      return 2; // C — +1
    return 3;                         // D — +0
  }

  String get _formatted {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primaryA.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primaryA.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(Icons.psychology_outlined,
                  color: AppColors.primaryA, size: 44),
              const SizedBox(height: 12),
              const Text(
                'Focus Timer Task',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _running
                    ? 'Stay focused on this screen.\nTap STOP the moment your mind wanders.'
                    : _done
                        ? 'Great — your result has been recorded.'
                        : 'Tap START, then stay focused.\nTap STOP when your mind wanders to something else.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Timer display
        Text(
          _formatted,
          style: TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.bold,
            color: _running ? AppColors.primaryA : Colors.grey[600],
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),

        const SizedBox(height: 32),

        if (!_done) ...[
          SizedBox(
            width: double.infinity,
            height: 52,
            child: _running
                ? ElevatedButton.icon(
                    onPressed: _stop,
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text('My mind just wandered',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: _start,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start Timer',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryA,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
          ),
        ] else ...[
          // Show result and confirm
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'You focused for $_formatted',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => widget.onDone(_toOptionIndex()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryA,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Next', style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Q6 — Re-read Tracker Task
// Show a short paragraph. User taps "Re-read" every time they lose focus.
// Count of re-reads → mapped to A/B/C/D: 0=A  1-2=B  3-4=C  5+=D
// ─────────────────────────────────────────────────────────────────────────────
class _RereadTrackerTask extends StatefulWidget {
  final void Function(int optionIndex) onDone;
  const _RereadTrackerTask({required this.onDone});

  @override
  State<_RereadTrackerTask> createState() => _RereadTrackerTaskState();
}

class _RereadTrackerTaskState extends State<_RereadTrackerTask> {
  int _rereads = 0;
  bool _finished = false;

  static const String _passage =
      'The human brain is remarkably adaptable, but it requires consistent '
      'stimulation to maintain peak cognitive performance. Research has shown '
      'that regular reading, problem-solving, and focused work sessions '
      'strengthen neural pathways associated with sustained attention. '
      'In contrast, fragmented screen time — characterized by rapid switching '
      'between short content — has been linked to reduced working memory '
      'capacity and lower ability to engage in deep, focused thinking.';

  int _toOptionIndex() {
    if (_rereads == 0)       return 0; // A — +5
    if (_rereads <= 2)       return 1; // B — +3
    if (_rereads <= 4)       return 2; // C — +1
    return 3;                          // D — +0
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[700]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.menu_book_outlined,
                      color: AppColors.primaryA, size: 18),
                  const SizedBox(width: 8),
                  Text('Read this passage carefully',
                      style: TextStyle(
                          color: AppColors.primaryA,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _passage,
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Text(
          'Every time you lose focus and need to re-read a part, tap the button below.',
          style: TextStyle(color: Colors.grey[400], fontSize: 13),
        ),

        const SizedBox(height: 16),

        // Re-read counter
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _finished
                    ? null
                    : () => setState(() => _rereads++),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(
                  'I re-read something  ($_rereads)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Done reading button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => widget.onDone(_toOptionIndex()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryA,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Done Reading',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Q7–Q9 — Regular Option Cards (self-reported attention questions)
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...List.generate(4, (i) {
          final isSelected = _selected == i;
          final label = ['A', 'B', 'C', 'D'][i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => setState(() => _selected = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: isSelected
                      ? LinearGradient(colors: [
                          AppColors.primaryA,
                          AppColors.primaryB
                        ])
                      : null,
                  color: isSelected ? null : Colors.white.withOpacity(0.05),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : Colors.grey[700]!,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? Colors.white
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? Colors.white
                              : Colors.grey[500]!,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.primaryA
                                : Colors.grey[400],
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
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
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed:
                _selected != null ? () => widget.onSelect(_selected!) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryA,
              disabledBackgroundColor: Colors.grey[800],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Next',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
