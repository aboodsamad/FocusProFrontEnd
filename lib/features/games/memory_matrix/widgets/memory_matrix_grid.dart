import 'package:flutter/material.dart';

import '../models/memory_matrix_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colors  (scoped to this file — same pattern as sudoku widgets)
// ─────────────────────────────────────────────────────────────────────────────

class _C {
  // Deep Focus dark-green palette (game stays dark, bg = AppColors.primary #012D1D)
  static const cellIdle   = Color(0xFF1B4332); // AppColors.primaryContainer
  static const cellBorder = Color(0xFF274E3D); // subtle edge
  static const highlight  = Color(0xFFA0F4C8); // AppColors.secondaryContainer — mint glow
  static const selected   = Color(0xFF85D7AD); // AppColors.secondaryFixedDim
  static const success    = Color(0xFF0E6C4A); // AppColors.secondary
  static const missed     = Color(0xFFFFAB40); // keep amber for missed cells
  static const wrong      = Color(0xFFBA1A1A); // AppColors.error
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

  /// Grid gap scales down for larger grids so cells stay a decent size.
  double get _spacing {
    if (gridSize >= 13) return 3.0;
    if (gridSize >= 11) return 4.0;
    if (gridSize >= 9)  return 5.0;
    return 8.0;
  }

  /// Cell corner radius scales down for smaller cells.
  double get _cellRadius {
    if (gridSize >= 13) return 4.0;
    if (gridSize >= 11) return 6.0;
    if (gridSize >= 9)  return 8.0;
    return 12.0;
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:   gridSize,
        crossAxisSpacing: _spacing,
        mainAxisSpacing:  _spacing,
      ),
      itemCount: gridSize * gridSize,
      itemBuilder: (context, idx) {
        final row   = idx ~/ gridSize;
        final col   = idx % gridSize;
        final state = _resolveState(row, col);

        return GestureDetector(
          onTap: () => onCellTap(row, col),
          child: _MemoryCell(
            state:      state,
            animation:  cellAnimations[idx]!,
            cellRadius: _cellRadius,
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
  final double cellRadius;

  const _MemoryCell({required this.state, required this.animation, required this.cellRadius});

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
              borderRadius: BorderRadius.circular(cellRadius),
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
