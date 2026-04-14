import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Animated pulsing circle that displays the user's focus score.
/// Updated to use the Deep Focus design system colors.
class FocusCircle extends StatelessWidget {
  final double score;
  final AnimationController pulseController;

  const FocusCircle({
    super.key,
    required this.score,
    required this.pulseController,
    // Legacy parameters kept for backward compatibility
    Color primaryA = AppColors.primary,
    Color primaryB = AppColors.primaryContainer,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1 + pulseController.value * 0.03,
          child: child,
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 200,
            height: 200,
            child: CustomPaint(
              painter: RingPainter(score / 100),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score.toStringAsFixed(0),
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  height: 1.0,
                ),
              ),
              const Text(
                'FOCUS SCORE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Draws the arc-ring progress indicator for the Deep Focus design.
class RingPainter extends CustomPainter {
  final double pct;

  RingPainter(this.pct);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final center = (Offset.zero & size).center;
    final radius = (math.min(size.width, size.height) - stroke) / 2;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = AppColors.surfaceContainerHigh,
    );

    if (pct > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * pct,
        false,
        Paint()
          ..color = AppColors.primaryContainer
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant RingPainter old) => old.pct != pct;
}
