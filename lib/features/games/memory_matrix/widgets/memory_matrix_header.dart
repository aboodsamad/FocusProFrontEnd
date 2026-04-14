import 'package:capstone_front_end/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MemoryMatrixScoreChip
// ─────────────────────────────────────────────────────────────────────────────

/// Shows current score and level in the top bar.
class MemoryMatrixScoreChip extends StatelessWidget {
  final int score;
  final int level;

  const MemoryMatrixScoreChip({
    super.key,
    required this.score,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, color: AppColors.primaryFixed, size: 14),
          const SizedBox(width: 4),
          Text(
            '$score',
            style: const TextStyle(
              color:      AppColors.onPrimary,
              fontWeight: FontWeight.w700,
              fontSize:   14,
            ),
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 12, color: AppColors.onPrimaryContainer),
          const SizedBox(width: 8),
          Text(
            'Lv $level',
            style: const TextStyle(
              color:      AppColors.onPrimaryContainer,
              fontSize:   12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MemoryMatrixLivesRow
// ─────────────────────────────────────────────────────────────────────────────

/// Three heart icons indicating remaining lives.
class MemoryMatrixLivesRow extends StatelessWidget {
  final int lives;
  static const int maxLives = 3;

  const MemoryMatrixLivesRow({super.key, required this.lives});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        maxLives,
        (i) => Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Icon(
            Icons.favorite_rounded,
            size:  18,
            color: i < lives ? AppColors.error : AppColors.primaryContainer,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MemoryMatrixStatusLabel
// ─────────────────────────────────────────────────────────────────────────────

/// Instruction pill shown above the grid ('Watch carefully…', 'Select X cells', …).
class MemoryMatrixStatusLabel extends StatelessWidget {
  final String text;

  const MemoryMatrixStatusLabel({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color:        AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color:      AppColors.onPrimaryContainer,
          fontSize:   14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MemoryMatrixTimerRing
// ─────────────────────────────────────────────────────────────────────────────

/// Circular countdown ring shown during the input phase.
class MemoryMatrixTimerRing extends StatelessWidget {
  final int timeLeft;
  final int totalTime;

  const MemoryMatrixTimerRing({
    super.key,
    required this.timeLeft,
    required this.totalTime,
  });

  Color get _color {
    if (totalTime == 0) return AppColors.secondaryContainer;
    final fraction = timeLeft / totalTime;
    if (fraction > 0.5) return AppColors.secondaryContainer;
    if (fraction > 0.25) return const Color(0xFFFFD166);
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final fraction = totalTime > 0 ? (timeLeft / totalTime).clamp(0.0, 1.0) : 0.0;
    return SizedBox(
      width:  52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value:           fraction,
            backgroundColor: AppColors.primaryContainer,
            valueColor:      AlwaysStoppedAnimation<Color>(_color),
            strokeWidth:     4,
          ),
          Text(
            '$timeLeft',
            style: TextStyle(
              color:      _color,
              fontSize:   15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MemoryMatrixStatRow
// ─────────────────────────────────────────────────────────────────────────────

/// One row in the game-over stats card (label + coloured value).
class MemoryMatrixStatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color  valueColor;

  const MemoryMatrixStatRow({
    super.key,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color:        AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.onPrimaryContainer, fontSize: 14),
          ),
          Text(
            value,
            style: TextStyle(
              color:      valueColor,
              fontSize:   16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
