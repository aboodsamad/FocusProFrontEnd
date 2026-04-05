import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colours
// ─────────────────────────────────────────────────────────────────────────────

const _kCellBase    = Color(0xFF0A0F1C);
const _kCellCross   = Color(0xFF111D35); // same row or col
const _kCellBox     = Color(0xFF0E1628); // same 3×3 box
const _kCellSame    = Color(0xFF1E1B4B); // same digit
const _kCellSelect  = Color(0xFF3730A3); // selected cell
const _kCellError   = Color(0xFF450A0A); // conflict
const _kBorderInner = Color(0xFF1C2540);
const _kBorderBox   = Color(0xFF3B4668);
const _kNumFixed    = Colors.white;
const _kNumUser     = Color(0xFF818CF8);
const _kNumSame     = Color(0xFFA5B4FC);
const _kNumError    = Color(0xFFEF4444);
const _kPrimary     = Color(0xFF6366F1);

// ─────────────────────────────────────────────────────────────────────────────
// SudokuBoard
// ─────────────────────────────────────────────────────────────────────────────

class SudokuBoard extends StatelessWidget {
  final List<List<int>>  board;
  final List<List<int>>  solution;
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
    final v = board[row][col];
    if (v == 0) return false;
    for (int c = 0; c < 9; c++) if (c != col && board[row][c] == v) return true;
    for (int r = 0; r < 9; r++) if (r != row && board[r][col] == v) return true;
    final br = (row ~/ 3) * 3, bc = (col ~/ 3) * 3;
    for (int r = br; r < br + 3; r++) {
      for (int c = bc; c < bc + 3; c++) {
        if ((r != row || c != col) && board[r][c] == v) return true;
      }
    }
    return false;
  }

  // ── Cell background colour — priority order ──────────────────────────────

  Color _cellBg(int row, int col) {
    final value      = board[row][col];
    final selVal     = (selectedRow != null && selectedCol != null)
        ? board[selectedRow!][selectedCol!]
        : 0;
    final isSelected   = selectedRow == row && selectedCol == col;
    final isInCross    = !isSelected &&
        (selectedRow == row || selectedCol == col);
    final isInBox      = !isSelected && !isInCross &&
        selectedRow != null && selectedCol != null &&
        (row ~/ 3) == (selectedRow! ~/ 3) &&
        (col ~/ 3) == (selectedCol! ~/ 3);
    final isSameNum    = selVal != 0 && value == selVal && !isSelected;
    final hasError     = !isFixed[row][col] && value != 0 && _hasConflict(row, col);

    if (isSelected)                return _kCellSelect;
    if (hasError)                  return _kCellError;
    if (isSameNum && isInCross)    return const Color(0xFF262057); // overlap
    if (isSameNum)                 return _kCellSame;
    if (isInCross)                 return _kCellCross;
    if (isInBox)                   return _kCellBox;
    return _kCellBase;
  }

  // ── Cell digit colour ────────────────────────────────────────────────────

  Color _numColor(int row, int col) {
    final value      = board[row][col];
    final selVal     = (selectedRow != null && selectedCol != null)
        ? board[selectedRow!][selectedCol!]
        : 0;
    final isSelected  = selectedRow == row && selectedCol == col;
    final isSameNum   = selVal != 0 && value == selVal && !isSelected;
    final hasError    = !isFixed[row][col] && value != 0 && _hasConflict(row, col);

    if (hasError)          return _kNumError;
    if (isSelected)        return Colors.white;
    if (isSameNum)         return _kNumSame;
    if (isFixed[row][col]) return _kNumFixed;
    return _kNumUser;
  }

  // ── Cell builder ─────────────────────────────────────────────────────────

  Widget _buildCell(int row, int col, double size) {
    final value      = board[row][col];
    final isSelected = selectedRow == row && selectedCol == col;

    // Thicker lines at every 3rd box boundary
    final isBoxTop    = row % 3 == 0;
    final isBoxLeft   = col % 3 == 0;
    final isBoxRight  = col == 8 || col % 3 == 2;
    final isBoxBottom = row == 8 || row % 3 == 2;

    return GestureDetector(
      onTap: () => onCellTap(row, col),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        width: size, height: size,
        decoration: BoxDecoration(
          color: _cellBg(row, col),
          border: Border(
            top:    BorderSide(width: isBoxTop    ? 1.8 : 0.5, color: isBoxTop    ? _kBorderBox : _kBorderInner),
            left:   BorderSide(width: isBoxLeft   ? 1.8 : 0.5, color: isBoxLeft   ? _kBorderBox : _kBorderInner),
            right:  BorderSide(width: isBoxRight  ? 1.8 : 0.5, color: isBoxRight  ? _kBorderBox : _kBorderInner),
            bottom: BorderSide(width: isBoxBottom ? 1.8 : 0.5, color: isBoxBottom ? _kBorderBox : _kBorderInner),
          ),
        ),
        child: value == 0
            ? null
            : Center(
                child: Text(
                  value.toString(),
                  style: TextStyle(
                    fontSize:   size * 0.47,
                    fontWeight: isFixed[row][col] ? FontWeight.w700 : FontWeight.w600,
                    color:      _numColor(row, col),
                    shadows: isSelected
                        ? [Shadow(color: Colors.white.withOpacity(0.55), blurRadius: 10)]
                        : null,
                  ),
                ),
              ),
      ),
    );
  }

  // ── Board ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCellBase,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: _kPrimary.withOpacity(0.18), blurRadius: 28, spreadRadius: 2),
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            final size = constraints.maxWidth / 9;
            return Column(
              children: List.generate(9, (row) => Row(
                children: List.generate(9, (col) => _buildCell(row, col, size)),
              )),
            );
          },
        ),
      ),
    );
  }
}
