import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Clean icon badge used in auth screens.
/// Shows a rounded-square container with a primary-colored icon — no rotation,
/// no purple gradient. The [scaleAnimation] and [rotationAnimation] parameters
/// are kept for API compatibility but only scale is applied; rotation is ignored.
class AnimatedLogo extends StatelessWidget {
  final Animation<double> scaleAnimation;
  // Kept for API compatibility — not used for rotation any more.
  final Animation<double> rotationAnimation;
  final IconData icon;

  const AnimatedLogo({
    super.key,
    required this.scaleAnimation,
    required this.rotationAnimation,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: scaleAnimation,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.18),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.onPrimary, size: 36),
      ),
    );
  }
}
