import 'package:flutter/material.dart';

import '../models/memory_matrix_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colors  (scoped to this file — same pattern as sudoku widgets)
// ─────────────────────────────────────────────────────────────────────────────

class _C {
  static const cellIdle   = Color(0xFF151C2E);
  static const cellBorder = Color(0xFF1E2840);
  static const highlight  = Color(0xFF7B6FFF);
  static const selected   = Color(0xFF48C9FF);
  static const success    = Color(0xFF3DD68C);
  static const missed     = Color(0xFFFFAB40);
  static const wrong      = Color(0xFFFF5270);
}

// ─────────────────────────────────────────────────────────────────────────────
// MemoryMatrixGrid
// ─────────────────────────────────────────────────────────────────────────────

/// The 4 × 4 interactive grid.
/// Receives cell state via [cellState] resolver and fires [onCellTap].
class MemoryMatrixGrid extends StatelessWidget {
  final int gridSize;
  final MemoryMatrixPhase phase;
  final List<List<bool>> pattern;
  final List<List<bool>> playerInput;
  final Set<int> highlightedCells;

  /// Per-cell scale animations driven by the page's [AnimationController] map.
  final Map<int, Animation<double>> cellAnimations;

  final void Function(int row, int col) onCellTap;

  const MemoryMatrixGrid({
    super.key,
    required this.gridSize,
    required this.phase,
    required this.pattern,
    required this.playerInput,
    required this.highlightedCells,
    required this.cellAnimations,
    required this.onCellTap,
  });

  MemoryMatrixCellState _resolveState(int row, int col) {
    final idx          = row * gridSize + col;
    final isHighlighted = highlightedCells.contains(idx);
    final isSelected    = playerInput[row][col];
    final isPatternCell = pattern[row][col];

    switch (phase) {
      case MemoryMatrixPhase.showing:
        return isHighlighted ? MemoryMatrixCellState.highlighted : MemoryMatrixCellState.idle;

      case MemoryMatrixPhase.input:
        return isSelected ? MemoryMatrixCellState.selected : MemoryMatrixCellState.idle;

      case MemoryMatrixPhase.checking:
        if (isPatternCell && isSelected)  return MemoryMatrixCellState.correct;
        if (isPatternCell && !isSelected) return MemoryMatrixCellState.missed;
        if (!isPatternCell && isSelected) return MemoryMatrixCellState.wrong;
        return MemoryMatrixCellState.idle;

      default:
        return MemoryMatrixCellState.idle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:  gridSize,
        crossAxisSpacing: 10,
        mainAxisSpacing:  10,
      ),
      itemCount: gridSize * gridSize,
      itemBuilder: (context, idx) {
        final row   = idx ~/ gridSize;
        final col   = idx % gridSize;
        final state = _resolveState(row, col);

        return GestureDetector(
          onTap: () => onCellTap(row, col),
          child: _MemoryCell(
            state:     state,
            animation: cellAnimations[idx]!,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MemoryCell  (private — only used by MemoryMatrixGrid)
// ─────────────────────────────────────────────────────────────────────────────

class _MemoryCell extends StatelessWidget {
  final MemoryMatrixCellState state;
  final Animation<double> animation;

  const _MemoryCell({required this.state, required this.animation});

  Color get _bg {
    switch (state) {
      case MemoryMatrixCellState.highlighted: return _C.highlight;
      case MemoryMatrixCellState.selected:    return _C.selected.withOpacity(0.75);
      case MemoryMatrixCellState.correct:     return _C.success;
      case MemoryMatrixCellState.missed:      return _C.missed;
      case MemoryMatrixCellState.wrong:       return _C.wrong;
      case MemoryMatrixCellState.idle:        return _C.cellIdle;
    }
  }

  Color get _glow {
    switch (state) {
      case MemoryMatrixCellState.highlighted: return _C.highlight.withOpacity(0.55);
      case MemoryMatrixCellState.selected:    return _C.selected.withOpacity(0.35);
      case MemoryMatrixCellState.correct:     return _C.success.withOpacity(0.45);
      case MemoryMatrixCellState.missed:      return _C.missed.withOpacity(0.4);
      case MemoryMatrixCellState.wrong:       return _C.wrong.withOpacity(0.4);
      case MemoryMatrixCellState.idle:        return Colors.transparent;
    }
  }

  bool get _isActive => state != MemoryMatrixCellState.idle;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final scale = _isActive ? (0.88 + 0.12 * animation.value) : 1.0;
        return Transform.scale(
          scale: scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color:         _bg,
              border: Border.all(
                color: state == MemoryMatrixCellState.idle
                    ? _C.cellBorder
                    : _bg.withOpacity(0.6),
                width: 1.2,
              ),
              boxShadow: _isActive
                  ? [BoxShadow(color: _glow, blurRadius: 16, spreadRadius: 1)]
                  : null,
            ),
          ),
        );
      },
    );
  }
}
