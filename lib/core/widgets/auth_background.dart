import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Plain surface-colored background shared by [LoginPage] and [SignupPage].
/// No gradient — just a light #F8F9FA scaffold.
class AuthBackground extends StatelessWidget {
  final Widget child;

  const AuthBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
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
    );
  }
}
