import 'package:flutter/material.dart';

/// Single source of truth for every color used in the app.
/// Instead of Color(0xFF667eea) scattered across 10 files,
/// you change it here once and it updates everywhere.
class AppColors {
  AppColors._();

  // ── Brand gradient ─────────────────────────────────────────────────────────
  static const Color primaryA     = Color(0xFF667eea);  // purple-blue
  static const Color primaryB     = Color(0xFF764ba2);  // deep purple
  static const Color primaryC     = Color(0xFFf093fb);  // pink (gradient end)

  // ── Backgrounds ────────────────────────────────────────────────────────────
  static const Color softBg       = Color(0xFFF7F8FA);  // pages background
  static const Color cardBg       = Colors.white;

  // ── Text ───────────────────────────────────────────────────────────────────
  static const Color textDark     = Color(0xFF333333);
  static const Color textMedium   = Color(0xFF1F2937);

  // ── Sudoku specific ────────────────────────────────────────────────────────
  static const Color sudokuPrimary   = Color(0xFF6366F1);
  static const Color sudokuBg        = Color(0xFFF5F5F7);
  static const Color sudokuSelected  = Color(0xFF93C5FD);

  // ── Auth screen gradient ───────────────────────────────────────────────────
  static const List<Color> authGradient = [primaryA, primaryB, primaryC];
  static const List<double> authGradientStops = [0.0, 0.5, 1.0];
}
