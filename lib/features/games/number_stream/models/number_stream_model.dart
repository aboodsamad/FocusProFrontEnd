/// Pure-Dart model — no Flutter dependency.
/// Holds all game state for the Number Stream game.

import 'dart:math';

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────

enum NumberStreamPhase { idle, countdown, playing, levelUp, gameOver }

enum MathOp { add, subtract, multiply }

// ─────────────────────────────────────────────────────────────────────────────
// Equation
// ─────────────────────────────────────────────────────────────────────────────

class StreamEquation {
  final int id;
  final int a;
  final int b;
  final MathOp op;

  /// Four answer choices (one correct, three distractors) in shuffled order.
  final List<int> choices;

  const StreamEquation({
    required this.id,
    required this.a,
    required this.b,
    required this.op,
    required this.choices,
  });

  int get answer {
    switch (op) {
      case MathOp.add:      return a + b;
      case MathOp.subtract: return a - b;
      case MathOp.multiply: return a * b;
    }
  }

  String get expression {
    final sym = op == MathOp.add ? '+' : op == MathOp.subtract ? '−' : '×';
    return '$a  $sym  $b';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Game state
// ─────────────────────────────────────────────────────────────────────────────

class NumberStreamState {
  final int level;
  final int score;
  final int lives;
  final int streak;
  final int bestStreak;
  final NumberStreamPhase phase;

  /// Equations solved correctly in the current level.
  final int solved;

  /// How many correct answers needed to level up.
  final int perLevel;

  final int countdown;

  /// The equation currently falling. Null when between equations.
  final StreamEquation? equation;

  const NumberStreamState({
    required this.level,
    required this.score,
    required this.lives,
    required this.streak,
    required this.bestStreak,
    required this.phase,
    required this.solved,
    required this.perLevel,
    required this.countdown,
    this.equation,
  });

  factory NumberStreamState.initial() => const NumberStreamState(
        level:      1,
        score:      0,
        lives:      3,
        streak:     0,
        bestStreak: 0,
        phase:      NumberStreamPhase.idle,
        solved:     0,
        perLevel:   8,
        countdown:  3,
      );

  NumberStreamState copyWith({
    int?                  level,
    int?                  score,
    int?                  lives,
    int?                  streak,
    int?                  bestStreak,
    NumberStreamPhase?    phase,
    int?                  solved,
    int?                  perLevel,
    int?                  countdown,
    StreamEquation?       equation,
    bool                  clearEquation = false,
  }) {
    return NumberStreamState(
      level:      level      ?? this.level,
      score:      score      ?? this.score,
      lives:      lives      ?? this.lives,
      streak:     streak     ?? this.streak,
      bestStreak: bestStreak ?? this.bestStreak,
      phase:      phase      ?? this.phase,
      solved:     solved     ?? this.solved,
      perLevel:   perLevel   ?? this.perLevel,
      countdown:  countdown  ?? this.countdown,
      equation:   clearEquation ? null : (equation ?? this.equation),
    );
  }

  // ── Derived helpers ────────────────────────────────────────────────────────

  /// Fall duration in milliseconds — decreases by 350 ms per level (floor 2 000).
  int get fallDurationMs {
    final ms = 5200 - ((level - 1) * 350);
    return ms < 2000 ? 2000 : ms;
  }

  /// Base points for a correct answer (streak multiplies the bonus).
  int get answerPoints => 100 * level + (streak * 20);

  /// Fraction of the level completed [0.0 – 1.0].
  double get levelProgress => perLevel > 0 ? solved / perLevel : 0;
}

// ─────────────────────────────────────────────────────────────────────────────
// Equation generator
// ─────────────────────────────────────────────────────────────────────────────

int _eqCounter = 0;

StreamEquation generateEquation(int level) {
  final rng = Random();
  final id  = ++_eqCounter;

  MathOp op;
  int a, b;

  if (level == 1) {
    op = MathOp.add;
    a  = rng.nextInt(9) + 1;
    b  = rng.nextInt(9) + 1;
  } else if (level == 2) {
    op = rng.nextBool() ? MathOp.add : MathOp.subtract;
    a  = rng.nextInt(19) + 2;
    b  = op == MathOp.subtract ? rng.nextInt(a - 1) + 1 : rng.nextInt(19) + 1;
  } else if (level == 3) {
    op = rng.nextBool() ? MathOp.add : MathOp.subtract;
    a  = rng.nextInt(29) + 2;
    b  = op == MathOp.subtract ? rng.nextInt(a - 1) + 1 : rng.nextInt(29) + 1;
  } else if (level == 4) {
    op = MathOp.multiply;
    a  = rng.nextInt(8) + 2;
    b  = rng.nextInt(8) + 2;
  } else {
    final ops = MathOp.values;
    op = ops[rng.nextInt(ops.length)];
    if (op == MathOp.multiply) {
      a = rng.nextInt(11) + 2;
      b = rng.nextInt(11) + 2;
    } else {
      a = rng.nextInt(49) + 2;
      b = op == MathOp.subtract ? rng.nextInt(a - 1) + 1 : rng.nextInt(49) + 1;
    }
  }

  final correct = op == MathOp.add      ? a + b
                : op == MathOp.subtract ? a - b
                :                         a * b;

  final range  = level <= 2 ? 10 : level <= 4 ? 18 : 25;
  final wrongs = <int>{};
  while (wrongs.length < 3) {
    final delta     = rng.nextInt(range) + 1;
    final candidate = correct + (rng.nextBool() ? delta : -delta);
    if (candidate != correct && candidate >= 0) wrongs.add(candidate);
  }

  final choices = [correct, ...wrongs]..shuffle(rng);

  return StreamEquation(id: id, a: a, b: b, op: op, choices: choices);
}
