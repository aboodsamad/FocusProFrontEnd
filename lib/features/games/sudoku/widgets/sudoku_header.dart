import 'package:capstone_front_end/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SudokuInfoCard  — timer / mistakes stat chip
// ─────────────────────────────────────────────────────────────────────────────

class SudokuInfoCard extends StatelessWidget {
  final IconData icon;
  final String   text;
  final Color?   iconColor;

  const SudokuInfoCard({
    super.key,
    required this.icon,
    required this.text,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color:        AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 7),
          Text(
            text,
            style: const TextStyle(
              fontSize:   16,
              fontWeight: FontWeight.bold,
              color:      AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SudokuDifficultySelector
// ─────────────────────────────────────────────────────────────────────────────

class SudokuDifficultySelector extends StatelessWidget {
  final String              difficulty;
  final ValueChanged<String> onSelected;

  const SudokuDifficultySelector({
    super.key,
    required this.difficulty,
    required this.onSelected,
  });

  Color get _diffColor {
    switch (difficulty) {
      case 'Easy':   return AppColors.secondary;
      case 'Hard':   return AppColors.error;
      default:       return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      initialValue: difficulty,
      onSelected:   onSelected,
      color:        AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color:        AppColors.secondaryContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              difficulty,
              style: const TextStyle(
                color:      AppColors.onSecondaryContainer,
                fontSize:   14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.onSecondaryContainer, size: 18),
          ],
        ),
      ),
      itemBuilder: (_) => [
        _menuItem('Easy',   AppColors.secondary),
        _menuItem('Medium', AppColors.primary),
        _menuItem('Hard',   AppColors.error),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(String label, Color color) {
    return PopupMenuItem(
      value: label,
      child: Text(
        label,
        style: TextStyle(
          color:      difficulty == label ? color : AppColors.onSurfaceVariant,
          fontWeight: difficulty == label ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SudokuStatRow  — used inside the win dialog
// ─────────────────────────────────────────────────────────────────────────────

class SudokuStatRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;

  const SudokuStatRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding:    const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color:        AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Text('$label:', style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: AppColors.onSurface, fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
