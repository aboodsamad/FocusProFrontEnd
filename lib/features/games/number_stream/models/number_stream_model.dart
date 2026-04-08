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

  /// Total wrong answers + missed equations across the whole game session.
  final int mistakes;

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
    required this.mistakes,
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
        mistakes:   0,
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
    int?                  mistakes,
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
      mistakes:   mistakes   ?? this.mistakes,
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

/// Resets the equation ID counter — call this at the start of each new game.
void resetEqCounter() => _eqCounter = 0;

StreamEquation generateEquation(int level) {
  final rng = Random();
  final id  = ++_eqCounter;

  MathOp op;
  int a, b;

  if (level == 1) {
    // Two-digit add/subtract — no more 3+2 trivia
    op = rng.nextBool() ? MathOp.add : MathOp.subtract;
    a  = rng.nextInt(26) + 15;                          // 15–40
    b  = op == MathOp.subtract
        ? rng.nextInt(a - 5) + 5                        // b in [5, a-1]
        : rng.nextInt(21) + 10;                         // 10–30
  } else if (level == 2) {
    // Add/subtract with bigger ranges, or small multiply
    final roll = rng.nextInt(3);
    if (roll == 0) {
      op = MathOp.multiply;
      a  = rng.nextInt(6) + 3;                          // 3–8
      b  = rng.nextInt(6) + 3;                          // 3–8
    } else {
      op = roll == 1 ? MathOp.add : MathOp.subtract;
      a  = rng.nextInt(41) + 20;                        // 20–60
      b  = op == MathOp.subtract
          ? rng.nextInt(a - 5) + 5
          : rng.nextInt(31) + 15;                       // 15–45
    }
  } else if (level == 3) {
    // All three ops equally; multiply goes up to ×12
    final ops = MathOp.values;
    op = ops[rng.nextInt(ops.length)];
    if (op == MathOp.multiply) {
      a = rng.nextInt(9) + 4;                           // 4–12
      b = rng.nextInt(9) + 4;
    } else {
      a = rng.nextInt(51) + 30;                         // 30–80
      b = op == MathOp.subtract
          ? rng.nextInt(a - 5) + 5
          : rng.nextInt(41) + 20;                       // 20–60
    }
  } else if (level == 4) {
    // Harder multiply; large add/subtract
    final ops = MathOp.values;
    op = ops[rng.nextInt(ops.length)];
    if (op == MathOp.multiply) {
      a = rng.nextInt(9) + 6;                           // 6–14
      b = rng.nextInt(9) + 6;
    } else {
      a = rng.nextInt(61) + 40;                         // 40–100
      b = op == MathOp.subtract
          ? rng.nextInt(a - 10) + 10
          : rng.nextInt(51) + 30;                       // 30–80
    }
  } else {
    // Level 5+: all ops, large numbers, multiply up to ×20
    final ops = MathOp.values;
    op = ops[rng.nextInt(ops.length)];
    if (op == MathOp.multiply) {
      a = rng.nextInt(13) + 8;                          // 8–20
      b = rng.nextInt(13) + 8;
    } else {
      a = rng.nextInt(101) + 50;                        // 50–150
      b = op == MathOp.subtract
          ? rng.nextInt(a - 10) + 10
          : rng.nextInt(71) + 30;                       // 30–100
    }
  }

  final correct = op == MathOp.add      ? a + b
                : op == MathOp.subtract ? a - b
                :                         a * b;

  // Tighter distractors so they're harder to dismiss at a glance
  final range  = level <= 2 ? 5 : level <= 4 ? 8 : 12;
  final wrongs = <int>{};
  while (wrongs.length < 3) {
    final delta     = rng.nextInt(range) + 1;
    final candidate = correct + (rng.nextBool() ? delta : -delta);
    if (candidate != correct && candidate >= 0) wrongs.add(candidate);
  }

  final choices = [correct, ...wrongs]..shuffle(rng);

  return StreamEquation(id: id, a: a, b: b, op: op, choices: choices);
}
