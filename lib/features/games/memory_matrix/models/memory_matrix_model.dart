/// Pure-Dart model.  No Flutter dependency.
///
/// Holds all game state for the Memory Matrix game.

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────

enum MemoryMatrixPhase { idle, countdown, showing, input, checking, levelUp, gameOver }

enum MemoryMatrixCellState {
  idle,
  highlighted,
  selected,
  correct,
  missed,
  wrong,
}

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

class MemoryMatrixState {
  final int level;
  final int score;
  final MemoryMatrixPhase phase;
  final int countdownValue;
  final int mistakes;

  /// Seconds remaining during the per-matrix input phase (counts down to 0).
  final int timeLeft;

  /// How many matrices have been shown in the current level (0–5).
  /// After 5 matrices, the level advances automatically.
  final int matricesInLevel;

  /// Which cells are part of the pattern (row × col booleans).
  final List<List<bool>> pattern;

  /// Which cells the player has tapped.
  final List<List<bool>> playerInput;

  /// Indices (row * gridSize + col) that are currently lit up.
  final Set<int> highlightedCells;

  const MemoryMatrixState({
    required this.level,
    required this.score,
    required this.phase,
    required this.countdownValue,
    required this.timeLeft,
    required this.matricesInLevel,
    required this.pattern,
    required this.playerInput,
    required this.highlightedCells,
    required this.mistakes,
  });

  factory MemoryMatrixState.initial(int gridSize) {
    return MemoryMatrixState(
      level: 1,
      score: 0,
      mistakes: 0,
      matricesInLevel: 0,
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
    int? mistakes,
    int? matricesInLevel,
    MemoryMatrixPhase? phase,
    int? countdownValue,
    int? timeLeft,
    List<List<bool>>? pattern,
    List<List<bool>>? playerInput,
    Set<int>? highlightedCells,
  }) {
    return MemoryMatrixState(
      level:            level            ?? this.level,
      score:            score            ?? this.score,
      phase:            phase            ?? this.phase,
      mistakes:         mistakes         ?? this.mistakes,
      matricesInLevel:  matricesInLevel  ?? this.matricesInLevel,
      countdownValue:   countdownValue   ?? this.countdownValue,
      timeLeft:         timeLeft         ?? this.timeLeft,
      pattern:          pattern          ?? this.pattern,
      playerInput:      playerInput      ?? this.playerInput,
      highlightedCells: highlightedCells ?? this.highlightedCells,
    );
  }

  // ── Derived helpers ────────────────────────────────────────────────────────

  /// Grid size per level: Level 1 = 5×5, Level 2 = 6×6, …, max 9×9.
  static int gridSizeForLevel(int level) {
    return (4 + level).clamp(5, 9);
  }

  /// How many matrices the player must attempt before levelling up.
  static const int matricesPerLevel = 5;

  /// Seconds for the per-matrix input phase; decreases with level.
  static int inputSecondsForLevel(int level) {
    return (30 - (level - 1) * 2).clamp(12, 30);
  }

  /// How many cells the player must remember this round.
  int cellsToRemember(int gridSize) {
    final maxCells = (gridSize * gridSize * 0.30).round();
    final count    = 3 + level;
    return count.clamp(3, maxCells);
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

  /// Points awarded for a correctly answered matrix.
  int roundPoints(int gridSize) => cellsToRemember(gridSize) * 10 + (level * 5);

  // Kept for backward compat (not displayed).
  int get lives => 3;
}
