/// Pure-Dart model.  No Flutter dependency.
///
/// Holds all game state for the Memory Matrix game.
/// The page reads and mutates this via copyWith or direct field access.

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────

/// The phase the game is currently in.
enum MemoryMatrixPhase { idle, countdown, showing, input, checking, levelUp, gameOver }

/// The visual state of a single cell.
enum MemoryMatrixCellState {
  idle,
  highlighted, // pattern is being shown
  selected, // player tapped it
  correct, // right — player hit it
  missed, // pattern cell the player missed
  wrong, // player tapped a non-pattern cell
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
  final int mistakes;

  /// Seconds remaining during the input phase (counts down to 0).
  final int timeLeft;

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
    required this.timeLeft,
    required this.pattern,
    required this.playerInput,
    required this.highlightedCells,
    required this.mistakes,
  });

  /// Default initial state shown on the idle screen.
  factory MemoryMatrixState.initial(int gridSize) {
    return MemoryMatrixState(
      level: 1,
      score: 0,
      lives: 3,
      mistakes: 0,
      phase: MemoryMatrixPhase.idle,
      countdownValue: 3,
      timeLeft: inputSecondsForLevel(1),
      pattern: List.generate(gridSize, (_) => List.filled(gridSize, false)),
      playerInput: List.generate(gridSize, (_) => List.filled(gridSize, false)),
      highlightedCells: {},
    );
  }

  MemoryMatrixState copyWith({
    int? level,
    int? score,
    int? lives,
    int? mistakes,
    MemoryMatrixPhase? phase,
    int? countdownValue,
    int? timeLeft,
    List<List<bool>>? pattern,
    List<List<bool>>? playerInput,
    Set<int>? highlightedCells,
  }) {
    return MemoryMatrixState(
      level: level ?? this.level,
      score: score ?? this.score,
      lives: lives ?? this.lives,
      phase: phase ?? this.phase,
      mistakes: mistakes ?? this.mistakes,
      countdownValue: countdownValue ?? this.countdownValue,
      timeLeft: timeLeft ?? this.timeLeft,
      pattern: pattern ?? this.pattern,
      playerInput: playerInput ?? this.playerInput,
      highlightedCells: highlightedCells ?? this.highlightedCells,
    );
  }

  // ── Derived helpers ────────────────────────────────────────────────────────

  /// Grid size for a given level: 9×9 at level 1, grows by 1 per level, capped at 13×13.
  static int gridSizeForLevel(int level) {
    return (8 + level).clamp(9, 13);
  }

  /// Seconds the player has to recall the pattern, decreasing with each level.
  static int inputSecondsForLevel(int level) {
    return (32 - level * 2).clamp(10, 32);
  }

  /// How many cells the player must remember this round.
  /// Grows fast enough to be challenging on a large grid.
  int cellsToRemember(int gridSize) {
    final maxCells = (gridSize * gridSize * 0.28).round();
    final count = 4 + level * 2;
    return count.clamp(4, maxCells);
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
  int roundPoints(int gridSize) => cellsToRemember(gridSize) * 10 + (level * 5);
}
