import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// The full-screen gradient background shared by [LoginPage] and [SignupPage].
/// Wraps its child in gradient → SafeArea → Center → SingleChildScrollView.
class AuthBackground extends StatelessWidget {
  final Widget child;

  const AuthBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.authGradient,
            stops: AppColors.authGradientStops,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
