import 'package:flutter/material.dart';
import '../models/diagnostic_question.dart';
import '../../../core/constants/app_colors.dart';

/// Progress header shown at the top of DiagnosticPage.
/// Shows current question number, dimension category, and a color-coded bar.
class DiagnosticProgressBar extends StatelessWidget {
  final int current;   // 0-based index
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
      case DiagnosticDimension.screenHabits: return Colors.pinkAccent;
      case DiagnosticDimension.attention:    return AppColors.primaryA;
      case DiagnosticDimension.lifestyle:    return Colors.green;
      case DiagnosticDimension.learning:     return Colors.orange;
    }
  }

  String get _dimensionLabel {
    switch (dimension) {
      case DiagnosticDimension.screenHabits: return '📱 Screen & Social Media';
      case DiagnosticDimension.attention:    return '🧠 Attention & Cognition';
      case DiagnosticDimension.lifestyle:    return '😴 Lifestyle Factors';
      case DiagnosticDimension.learning:     return '📚 Learning & Reading';
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (current + 1) / total;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _dimensionLabel,
                style: TextStyle(
                  color: _dimensionColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${current + 1} / $total',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation<Color>(_dimensionColor),
            ),
          ),
        ],
      ),
    );
  }
}
