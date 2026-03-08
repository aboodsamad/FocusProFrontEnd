import 'package:flutter/material.dart';

/// 9×9 Sudoku grid.
/// Extracted from `_buildBoard` and `_buildCell` in [_SudokuHomePageState].
class SudokuBoard extends StatelessWidget {
  final List<List<int>> board;
  final List<List<int>> solution;
  final List<List<bool>> isFixed;
  final int? selectedRow;
  final int? selectedCol;
  final void Function(int row, int col) onCellTap;

  const SudokuBoard({
    super.key,
    required this.board,
    required this.solution,
    required this.isFixed,
    required this.selectedRow,
    required this.selectedCol,
    required this.onCellTap,
  });

  // ── Conflict detection ───────────────────────────────────────────────────

  bool _hasConflict(int row, int col) {
    final value = board[row][col];
    if (value == 0) return false;

    for (int c = 0; c < 9; c++) {
      if (c != col && board[row][c] == value) return true;
    }
    for (int r = 0; r < 9; r++) {
      if (r != row && board[r][col] == value) return true;
    }

    final boxRow = (row ~/ 3) * 3;
    final boxCol = (col ~/ 3) * 3;
    for (int r = boxRow; r < boxRow + 3; r++) {
      for (int c = boxCol; c < boxCol + 3; c++) {
        if ((r != row || c != col) && board[r][c] == value) return true;
      }
    }
    return false;
  }

  // ── Cell builder ─────────────────────────────────────────────────────────

  Widget _buildCell(int row, int col, double size) {
    final isSelected = selectedRow == row && selectedCol == col;
    final value      = board[row][col];
    final isCellFixed = isFixed[row][col];
    final hasError   = !isCellFixed && value != 0 && _hasConflict(row, col);
    final isSameNumber = selectedRow != null &&
        selectedCol != null &&
        board[selectedRow!][selectedCol!] != 0 &&
        value == board[selectedRow!][selectedCol!];

    Color bgColor = Colors.white;
    if (isSelected) {
      bgColor = const Color(0xFF93C5FD);
    } else if (hasError) {
      bgColor = Colors.red.withOpacity(0.1);
    } else if (isSameNumber && value != 0) {
      bgColor = const Color(0xFF6366F1).withOpacity(0.05);
    } else if (selectedRow == row || selectedCol == col) {
      bgColor = const Color(0xFFF5F5F7);
    }

    return GestureDetector(
      onTap: () => onCellTap(row, col),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            top: BorderSide(
              width: row % 3 == 0 ? 3.0 : 1.0,
              color: Colors.black,
            ),
            left: BorderSide(
              width: col % 3 == 0 ? 3.0 : 1.0,
              color: Colors.black,
            ),
            right: col == 8
                ? const BorderSide(width: 3.0, color: Colors.black)
                : BorderSide.none,
            bottom: row == 8
                ? const BorderSide(width: 3.0, color: Colors.black)
                : BorderSide.none,
          ),
        ),
        child: Center(
          child: value == 0
              ? null
              : Text(
                  value.toString(),
                  style: TextStyle(
                    fontSize: size * 0.5,
                    fontWeight:
                        isCellFixed ? FontWeight.w900 : FontWeight.w600,
                    color: hasError
                        ? Colors.red
                        : isCellFixed
                            ? Colors.black
                            : const Color(0xFF6366F1),
                  ),
                ),
        ),
      ),
    );
  }

  // ── Board builder ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cellSize = constraints.maxWidth / 9;
            return Column(
              children: List.generate(9, (row) {
                return Row(
                  children: List.generate(9, (col) {
                    return _buildCell(row, col, cellSize);
                  }),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
