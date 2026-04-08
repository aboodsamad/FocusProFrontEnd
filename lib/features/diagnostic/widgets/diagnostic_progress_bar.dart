import 'package:flutter/material.dart';
import '../models/diagnostic_question.dart';
import '../../../core/constants/app_colors.dart';

/// Progress header shown at the top of DiagnosticPage.
/// Segmented bars (one per question) + dimension category label.
class DiagnosticProgressBar extends StatelessWidget {
  final int current; // 0-based index
  final int total;
  final DiagnosticDimension dimension;

  const DiagnosticProgressBar({
    super.key,
    required this.current,
    required this.total,
    required this.dimension,
  });

  Color get _dimensionColor {
    switch (dimension) {
      case DiagnosticDimension.screenHabits:
        return Colors.pinkAccent;
      case DiagnosticDimension.attention:
        return AppColors.primaryA;
      case DiagnosticDimension.lifestyle:
        return const Color(0xFF34D399);
      case DiagnosticDimension.learning:
        return Colors.orange;
    }
  }

  String get _dimensionLabel {
    switch (dimension) {
      case DiagnosticDimension.screenHabits:
        return 'Screen & Social Media';
      case DiagnosticDimension.attention:
        return 'Attention & Cognition';
      case DiagnosticDimension.lifestyle:
        return 'Lifestyle Factors';
      case DiagnosticDimension.learning:
        return 'Learning & Reading';
    }
  }

  IconData get _dimensionIcon {
    switch (dimension) {
      case DiagnosticDimension.screenHabits:
        return Icons.phone_android_rounded;
      case DiagnosticDimension.attention:
        return Icons.psychology_rounded;
      case DiagnosticDimension.lifestyle:
        return Icons.nights_stay_rounded;
      case DiagnosticDimension.learning:
        return Icons.auto_stories_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Segmented step bars
        Row(
          children: List.generate(total, (i) {
            final isDone = i < current;
            final isCurrent = i == current;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < total - 1 ? 4 : 0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOut,
                  height: 5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: (isDone || isCurrent)
                        ? LinearGradient(
                            colors: [
                              _dimensionColor,
                              _dimensionColor.withOpacity(0.65),
                            ],
                          )
                        : null,
                    color: (isDone || isCurrent) ? null : Colors.grey[850],
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: _dimensionColor.withOpacity(0.55),
                              blurRadius: 7,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        // Dimension label row
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _dimensionColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(_dimensionIcon,
                  color: _dimensionColor, size: 13),
            ),
            const SizedBox(width: 7),
            Text(
              _dimensionLabel,
              style: TextStyle(
                color: _dimensionColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: Colors.white.withOpacity(0.07)),
              ),
              child: Text(
                '${current + 1} of $total',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
