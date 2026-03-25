import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated pulsing circle that displays the user's focus score.
/// Extracted from `_buildFocusCircle` in [HomeScreen].
/// 
/// 
/// this file is not usedddddddd inthis project
class FocusCircle extends StatelessWidget {
  final double score;
  final AnimationController pulseController;
  final Color primaryA;
  final Color primaryB;

  const FocusCircle({
    super.key,
    required this.score,
    required this.pulseController,
    required this.primaryA,
    required this.primaryB,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1 + pulseController.value,
          child: child,
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: CustomPaint(
              painter: RingPainter(score / 100, primaryA, primaryB),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score.toStringAsFixed(0),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Text(
                'Focus',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Draws the arc-ring progress indicator behind [FocusCircle].
/// Extracted from `_RingPainter` in [HomeScreen].
class RingPainter extends CustomPainter {
  final double pct;
  final Color a;
  final Color b;

  RingPainter(this.pct, this.a, this.b);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final center = (Offset.zero & size).center;
    final radius = (math.min(size.width, size.height) - stroke) / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.grey.shade200,
    );

    final paint = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + 2 * math.pi * pct,
        colors: [a, b],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * pct,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant RingPainter old) => old.pct != pct;
}
