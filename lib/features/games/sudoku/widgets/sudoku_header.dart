import 'package:flutter/material.dart';

/// Timer / mistakes info chip shown in the Sudoku top bar.
/// Extracted from `_buildInfoCard` in [_SudokuHomePageState].
class SudokuInfoCard extends StatelessWidget {
  final IconData icon;
  final String text;

  const SudokuInfoCard({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF6366F1)),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }
}

/// Difficulty popup shown in the Sudoku top bar.
/// Extracted from `_buildDifficultySelector` in [_SudokuHomePageState].
class SudokuDifficultySelector extends StatelessWidget {
  final String difficulty;
  final ValueChanged<String> onSelected;

  const SudokuDifficultySelector({
    super.key,
    required this.difficulty,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      initialValue: difficulty,
      onSelected: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF6366F1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              difficulty,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: Colors.white),
          ],
        ),
      ),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'Easy',   child: Text('Easy')),
        PopupMenuItem(value: 'Medium', child: Text('Medium')),
        PopupMenuItem(value: 'Hard',   child: Text('Hard')),
      ],
    );
  }
}

/// One stat row used inside the win dialog (time / mistakes / hints).
/// Extracted from `_buildStatRow` in [_SudokuHomePageState].
class SudokuStatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const SudokuStatRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
