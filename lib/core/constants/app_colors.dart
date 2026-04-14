import 'package:flutter/material.dart';

/// Single source of truth for every color used in the app.
/// Derived from the "Deep Focus" design system (deep_focus/DESIGN.md).
class AppColors {
  AppColors._();

  // ── Primary ────────────────────────────────────────────────────────────────
  static const Color primary              = Color(0xFF012D1D); // deep forest green
  static const Color onPrimary            = Color(0xFFFFFFFF);
  static const Color primaryContainer     = Color(0xFF1B4332);
  static const Color onPrimaryContainer   = Color(0xFF86AF99);
  static const Color primaryFixed         = Color(0xFFC1ECD4);
  static const Color primaryFixedDim      = Color(0xFFA5D0B9);
  static const Color onPrimaryFixed       = Color(0xFF002114);
  static const Color onPrimaryFixedVariant= Color(0xFF274E3D);

  // ── Secondary ──────────────────────────────────────────────────────────────
  static const Color secondary              = Color(0xFF0E6C4A);
  static const Color onSecondary            = Color(0xFFFFFFFF);
  static const Color secondaryContainer     = Color(0xFFA0F4C8);
  static const Color onSecondaryContainer   = Color(0xFF19724F);
  static const Color secondaryFixed         = Color(0xFFA0F4C8);
  static const Color secondaryFixedDim      = Color(0xFF85D7AD);
  static const Color onSecondaryFixed       = Color(0xFF002113);
  static const Color onSecondaryFixedVariant= Color(0xFF005236);

  // ── Tertiary (slate blue — metrics & progress) ─────────────────────────────
  static const Color tertiary              = Color(0xFF00264E);
  static const Color onTertiary            = Color(0xFFFFFFFF);
  static const Color tertiaryContainer     = Color(0xFF0E3C6F);
  static const Color onTertiaryContainer   = Color(0xFF83A8E1);
  static const Color tertiaryFixed         = Color(0xFFD5E3FF);
  static const Color tertiaryFixedDim      = Color(0xFFA7C8FF);
  static const Color onTertiaryFixed       = Color(0xFF001C3B);
  static const Color onTertiaryFixedVariant= Color(0xFF1E477B);

  // ── Surface hierarchy ──────────────────────────────────────────────────────
  static const Color surface              = Color(0xFFF8F9FA); // base background
  static const Color surfaceBright        = Color(0xFFF8F9FA);
  static const Color surfaceDim           = Color(0xFFD9DADB);
  static const Color surfaceVariant       = Color(0xFFE1E3E4);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF); // card "lift"
  static const Color surfaceContainerLow    = Color(0xFFF3F4F5); // secondary bg
  static const Color surfaceContainer       = Color(0xFFEDEEEF);
  static const Color surfaceContainerHigh   = Color(0xFFE7E8E9); // input fields
  static const Color surfaceContainerHighest= Color(0xFFE1E3E4);

  // ── On-surface ─────────────────────────────────────────────────────────────
  static const Color onSurface            = Color(0xFF191C1D);
  static const Color onSurfaceVariant     = Color(0xFF414844);
  static const Color onBackground         = Color(0xFF191C1D);

  // ── Outline ────────────────────────────────────────────────────────────────
  static const Color outline              = Color(0xFF717973);
  static const Color outlineVariant       = Color(0xFFC1C8C2);

  // ── Error ──────────────────────────────────────────────────────────────────
  static const Color error                = Color(0xFFBA1A1A);
  static const Color onError              = Color(0xFFFFFFFF);
  static const Color errorContainer       = Color(0xFFFFDAD6);
  static const Color onErrorContainer     = Color(0xFF93000A);

  // ── Inverse ────────────────────────────────────────────────────────────────
  static const Color inverseSurface       = Color(0xFF2E3132);
  static const Color inverseOnSurface     = Color(0xFFF0F1F2);
  static const Color inversePrimary       = Color(0xFFA5D0B9);

  // ── Misc ───────────────────────────────────────────────────────────────────
  static const Color surfaceTint          = Color(0xFF3F6653);
  static const Color background           = Color(0xFFF8F9FA);
  static const Color scrim               = Color(0xFF000000);

  // ── Legacy aliases (kept to avoid breaking existing references) ────────────
  // These will be removed once all screens are updated.
  @Deprecated('Use AppColors.primary instead')
  static const Color primaryA = primary;
  @Deprecated('Use AppColors.primaryContainer instead')
  static const Color primaryB = primaryContainer;
  @Deprecated('Use AppColors.secondary instead')
  static const Color primaryC = secondary;
  @Deprecated('Use AppColors.surface instead')
  static const Color softBg = surface;
  @Deprecated('Use AppColors.surfaceContainerLowest instead')
  static const Color cardBg = surfaceContainerLowest;
  @Deprecated('Use AppColors.onSurface instead')
  static const Color textDark = onSurface;
  @Deprecated('Use AppColors.onSurface instead')
  static const Color textMedium = onSurface;
  @Deprecated('Use AppColors.primary instead')
  static const Color sudokuPrimary = primary;
  @Deprecated('Use AppColors.surface instead')
  static const Color sudokuBg = surface;
  @Deprecated('Use AppColors.primaryFixed instead')
  static const Color sudokuSelected = primaryFixed;
  static const List<Color> authGradient = [primary, primaryContainer];
  static const List<double> authGradientStops = [0.0, 1.0];
}
