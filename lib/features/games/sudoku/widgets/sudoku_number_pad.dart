import 'package:flutter/material.dart';

/// Row of 1–9 number buttons for the Sudoku input pad.
/// Extracted from `_buildNumberPad` and `_buildNumberButton` in [_SudokuHomePageState].
class SudokuNumberPad extends StatelessWidget {
  final List<List<int>> board;
  final void Function(int number) onNumberPressed;

  const SudokuNumberPad({
    super.key,
    required this.board,
    required this.onNumberPressed,
  });

  Widget _buildNumberButton(int number) {
    int count = 0;
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (board[r][c] == number) count++;
      }
    }
    final isComplete = count >= 9;

    return AspectRatio(
      aspectRatio: 1,
      child: Material(
        color: isComplete
            ? Colors.grey[300]
            : const Color(0xFF6366F1).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: isComplete ? null : () => onNumberPressed(number),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF6366F1).withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isComplete
                      ? Colors.grey[500]
                      : const Color(0xFF6366F1),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(9, (index) {
        final number = index + 1;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildNumberButton(number),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Hint + Erase action buttons shown below the number pad.
/// Extracted from `_buildActionButtons` and `_buildActionButton` in [_SudokuHomePageState].
class SudokuActionButtons extends StatelessWidget {
  final VoidCallback onHint;
  final VoidCallback onErase;

  const SudokuActionButtons({
    super.key,
    required this.onHint,
    required this.onErase,
  });

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.3), width: 2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            icon: Icons.lightbulb,
            label: 'Hint',
            color: Colors.amber,
            onPressed: onHint,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            icon: Icons.backspace,
            label: 'Erase',
            color: Colors.red,
            onPressed: onErase,
          ),
        ),
      ],
    );
  }
}
