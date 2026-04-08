import 'package:flutter/material.dart';
import '../models/diagnostic_question.dart';
import '../../../core/constants/app_colors.dart';

/// Used for screen_habits questions.
/// Shows a horizontal slider instead of A/B/C/D buttons.
/// Internally maps the slider position to the closest option and its points.
class SliderQuestionWidget extends StatefulWidget {
  final DiagnosticQuestion question;
  final void Function(DiagnosticAnswer answer) onAnswered;

  const SliderQuestionWidget({
    super.key,
    required this.question,
    required this.onAnswered,
  });

  @override
  State<SliderQuestionWidget> createState() => _SliderQuestionWidgetState();
}

class _SliderQuestionWidgetState extends State<SliderQuestionWidget> {
  // Slider maps 0.0 → option A, 1.0 → B, 2.0 → C, 3.0 → D
  double _sliderValue = 0.0;
  bool _hasInteracted = false;

  int get _selectedIndex => _sliderValue.round().clamp(0, 3);
  String get _selectedOption => ['A', 'B', 'C', 'D'][_selectedIndex];
  int get _selectedPoints => widget.question.points[_selectedIndex];
  String get _selectedLabel => widget.question.options[_selectedIndex];

  Color get _trackColor {
    // Green → Blue → Orange → Red as user slides right (worse habits)
    const colors = [
      Color(0xFF34D399), // green  (best)
      AppColors.primaryA, // blue
      Colors.orange, // orange
      Colors.redAccent, // red   (worst)
    ];
    return colors[_selectedIndex];
  }

  void _submit() {
    widget.onAnswered(DiagnosticAnswer(
      questionId: widget.question.id,
      selectedOption: _selectedOption,
      pointsEarned: _selectedPoints,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final opts = widget.question.options;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Selected answer display ──────────────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _trackColor.withOpacity(0.13),
                _trackColor.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: _trackColor.withOpacity(0.35), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _trackColor,
                      _trackColor.withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _trackColor.withOpacity(0.4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _selectedOption,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _hasInteracted
                      ? _selectedLabel
                      : 'Drag the slider to select your answer',
                  style: TextStyle(
                    color: _hasInteracted ? Colors.white : Colors.grey[500],
                    fontSize: 14,
                    fontWeight: _hasInteracted
                        ? FontWeight.w500
                        : FontWeight.normal,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // ── Slider ───────────────────────────────────────────────────────────
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _trackColor,
            inactiveTrackColor: Colors.grey[800],
            thumbColor: _trackColor,
            thumbShape:
                const RoundSliderThumbShape(enabledThumbRadius: 14),
            overlayColor: _trackColor.withOpacity(0.15),
            trackHeight: 6,
          ),
          child: Slider(
            value: _sliderValue,
            min: 0,
            max: 3,
            divisions: 3,
            onChanged: (val) {
              setState(() {
                _sliderValue = val;
                _hasInteracted = true;
              });
            },
          ),
        ),

        // ── Option labels below slider ────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(4, (i) {
              final isActive = _selectedIndex == i;
              return Expanded(
                child: Text(
                  opts[i],
                  textAlign: i == 0
                      ? TextAlign.left
                      : i == 3
                          ? TextAlign.right
                          : TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        isActive ? _trackColor : Colors.grey[700],
                    fontWeight: isActive
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 32),

        // ── Confirm button ────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 54,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _hasInteracted
                    ? [AppColors.primaryA, AppColors.primaryB]
                    : [Colors.grey[850]!, Colors.grey[850]!],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: _hasInteracted
                  ? [
                      BoxShadow(
                        color: AppColors.primaryA.withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: ElevatedButton(
              onPressed: _hasInteracted ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Confirm',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
