/// Pure-Dart model.  No Flutter dependency.
///
/// Holds all game state for the Memory Matrix game.
/// The page reads and mutates this via copyWith or direct field access.

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────

/// The phase the game is currently in.
enum MemoryMatrixPhase {
  idle,
  countdown,
  showing,
  input,
  checking,
  levelUp,
  gameOver,
}

/// The visual state of a single cell.
enum MemoryMatrixCellState {
  idle,
  highlighted,  // pattern is being shown
  selected,     // player tapped it
  correct,      // right — player hit it
  missed,       // pattern cell the player missed
  wrong,        // player tapped a non-pattern cell
}

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

/// Immutable snapshot of the game state.
/// The page creates a new instance whenever state changes.
class MemoryMatrixState {
  final int level;
  final int score;
  final int lives;
  final MemoryMatrixPhase phase;
  final int countdownValue;

  /// Which cells are part of the pattern (row × col booleans).
  final List<List<bool>> pattern;

  /// Which cells the player has tapped.
  final List<List<bool>> playerInput;

  /// Indices (row * gridSize + col) that are currently lit up.
  final Set<int> highlightedCells;

  const MemoryMatrixState({
    required this.level,
    required this.score,
    required this.lives,
    required this.phase,
    required this.countdownValue,
    required this.pattern,
    required this.playerInput,
    required this.highlightedCells,
  });

  /// Default initial state shown on the idle screen.
  factory MemoryMatrixState.initial(int gridSize) {
    return MemoryMatrixState(
      level:            1,
      score:            0,
      lives:            3,
      phase:            MemoryMatrixPhase.idle,
      countdownValue:   3,
      pattern:          List.generate(gridSize, (_) => List.filled(gridSize, false)),
      playerInput:      List.generate(gridSize, (_) => List.filled(gridSize, false)),
      highlightedCells: {},
    );
  }

  MemoryMatrixState copyWith({
    int?                    level,
    int?                    score,
    int?                    lives,
    MemoryMatrixPhase?      phase,
    int?                    countdownValue,
    List<List<bool>>?       pattern,
    List<List<bool>>?       playerInput,
    Set<int>?               highlightedCells,
  }) {
    return MemoryMatrixState(
      level:            level            ?? this.level,
      score:            score            ?? this.score,
      lives:            lives            ?? this.lives,
      phase:            phase            ?? this.phase,
      countdownValue:   countdownValue   ?? this.countdownValue,
      pattern:          pattern          ?? this.pattern,
      playerInput:      playerInput      ?? this.playerInput,
      highlightedCells: highlightedCells ?? this.highlightedCells,
    );
  }

  // ── Derived helpers ────────────────────────────────────────────────────────

  /// How many cells the player must remember this round.
  int cellsToRemember(int gridSize) {
    final max = gridSize * gridSize - 2;
    final count = 2 + level;
    return count < max ? count : max;
  }

  /// How many cells the player has selected so far.
  int get selectedCount {
    int count = 0;
    for (final row in playerInput) {
      for (final cell in row) {
        if (cell) count++;
      }
    }
    return count;
  }

  /// Points awarded for completing the current round.
  int get roundPoints => cellsToRemember(4) * 10 + (level * 5);
}
