import 'package:flutter/material.dart';

const _kPrimary = Color(0xFF6366F1);
const _kCardBg  = Color(0xFF0F1624);

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
    final color = iconColor ?? _kPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color:        _kCardBg,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.08), blurRadius: 10),
        ],
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
              color:      Colors.white,
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
      case 'Easy':   return const Color(0xFF10B981);
      case 'Hard':   return const Color(0xFFEF4444);
      default:       return _kPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      initialValue: difficulty,
      onSelected:   onSelected,
      color:        const Color(0xFF1A2235),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _kPrimary.withOpacity(0.25)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color:        _diffColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: _diffColor.withOpacity(0.4), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              difficulty,
              style: TextStyle(
                color:      _diffColor,
                fontSize:   14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, color: _diffColor, size: 18),
          ],
        ),
      ),
      itemBuilder: (_) => [
        _menuItem('Easy',   const Color(0xFF10B981)),
        _menuItem('Medium', _kPrimary),
        _menuItem('Hard',   const Color(0xFFEF4444)),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(String label, Color color) {
    return PopupMenuItem(
      value: label,
      child: Text(
        label,
        style: TextStyle(
          color:      difficulty == label ? color : Colors.white70,
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
              color:        _kPrimary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: _kPrimary),
          ),
          const SizedBox(width: 12),
          Text('$label:', style: const TextStyle(color: Colors.white60, fontSize: 14)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
