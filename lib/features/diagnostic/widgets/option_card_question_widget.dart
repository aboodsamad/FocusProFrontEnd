import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/diagnostic_question.dart';
import '../../../core/constants/app_colors.dart';

/// Used for lifestyle and learning dimension questions.
/// Tapping a card auto-advances to the next question after a brief highlight.
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
  bool _advancing = false;

  void _onTap(int i) {
    if (_advancing) return;
    HapticFeedback.lightImpact();
    setState(() {
      _selected = i;
      _advancing = true;
    });
    Future.delayed(const Duration(milliseconds: 380), () {
      if (!mounted) return;
      final letters = ['A', 'B', 'C', 'D'];
      widget.onAnswered(DiagnosticAnswer(
        questionId: widget.question.id,
        selectedOption: letters[i],
        pointsEarned: widget.question.points[i],
      ));
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
                  // Letter badge
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
                          color: isSelected
                              ? Colors.white
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
