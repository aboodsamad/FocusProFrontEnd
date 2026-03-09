import 'package:flutter/material.dart';
import '../models/diagnostic_question.dart';
import '../../../core/constants/app_colors.dart';

/// Used for lifestyle and learning dimension questions.
/// Clean card-based A/B/C/D selection — no slider, no timer.
class OptionCardQuestionWidget extends StatefulWidget {
  final DiagnosticQuestion question;
  final void Function(DiagnosticAnswer answer) onAnswered;

  const OptionCardQuestionWidget({
    super.key,
    required this.question,
    required this.onAnswered,
  });

  @override
  State<OptionCardQuestionWidget> createState() =>
      _OptionCardQuestionWidgetState();
}

class _OptionCardQuestionWidgetState
    extends State<OptionCardQuestionWidget> {
  int? _selected;

  void _submit() {
    if (_selected == null) return;
    final letters = ['A', 'B', 'C', 'D'];
    widget.onAnswered(DiagnosticAnswer(
      questionId:     widget.question.id,
      selectedOption: letters[_selected!],
      pointsEarned:   widget.question.points[_selected!],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...List.generate(4, (i) {
          final isSelected = _selected == i;
          final label = ['A', 'B', 'C', 'D'][i];

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () => setState(() => _selected = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: isSelected
                      ? const LinearGradient(colors: [
                          AppColors.primaryA,
                          AppColors.primaryB,
                        ])
                      : null,
                  color: isSelected ? null : Colors.white.withOpacity(0.05),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : Colors.grey[700]!,
                    width: 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primaryA.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    // Letter badge
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 32,
                      height: 32,
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
                          color: isSelected
                              ? Colors.white
                              : Colors.grey[300],
                          fontSize: 15,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),

                    if (isSelected)
                      const Icon(Icons.check_circle,
                          color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _selected != null ? _submit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryA,
              disabledBackgroundColor: Colors.grey[800],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
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
