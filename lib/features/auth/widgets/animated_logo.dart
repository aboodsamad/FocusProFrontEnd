import 'package:flutter/material.dart';

/// Spinning gradient circle with an icon.
/// Shared between [LoginPage] and [SignupPage].
class AnimatedLogo extends StatelessWidget {
  final Animation<double> scaleAnimation;
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
      child: AnimatedBuilder(
        animation: rotationAnimation,
        builder: (context, child) {
          return Transform.rotate(
            angle: rotationAnimation.value * 2 * 3.14159,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 40),
            ),
          );
        },
      ),
    );
  }
}
