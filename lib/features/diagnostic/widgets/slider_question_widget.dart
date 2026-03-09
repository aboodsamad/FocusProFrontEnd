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

  String get _selectedOption =>
      ['A', 'B', 'C', 'D'][_selectedIndex];

  int get _selectedPoints =>
      widget.question.points[_selectedIndex];

  String get _selectedLabel =>
      widget.question.options[_selectedIndex];

  Color get _trackColor {
    // Green → Yellow → Orange → Red as user slides right (worse habits)
    final colors = [AppColors.primaryA, AppColors.primaryA, Colors.orange, Colors.redAccent];
    return colors[_selectedIndex];
  }

  void _submit() {
    widget.onAnswered(DiagnosticAnswer(
      questionId:     widget.question.id,
      selectedOption: _selectedOption,
      pointsEarned:   _selectedPoints,
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
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _trackColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _trackColor.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _trackColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _selectedOption,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _hasInteracted ? _selectedLabel : 'Move the slider to answer',
                  style: TextStyle(
                    color: _hasInteracted ? Colors.white : Colors.grey[500],
                    fontSize: 15,
                    fontWeight: _hasInteracted ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── Slider ───────────────────────────────────────────────────────────
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor:   _trackColor,
            inactiveTrackColor: Colors.grey[800],
            thumbColor:         _trackColor,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
            overlayColor:       _trackColor.withOpacity(0.15),
            trackHeight:        6,
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
                    color: isActive ? _trackColor : Colors.grey[600],
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
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
          height: 52,
          child: ElevatedButton(
            onPressed: _hasInteracted ? _submit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryA,
              disabledBackgroundColor: Colors.grey[800],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  'Confirm',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
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
