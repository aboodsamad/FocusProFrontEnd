/// Pure-Dart model — no Flutter dependency.
/// Holds all game state for the Color Match (Stroop) game.

import 'dart:math';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────

enum ColorMatchPhase { idle, countdown, playing, gameOver }

enum ColorMatchDifficulty { easy, medium, hard }

// ─────────────────────────────────────────────────────────────────────────────
// Color entry
// ─────────────────────────────────────────────────────────────────────────────

class ColorEntry {
  final String name;
  final Color color;
  const ColorEntry({required this.name, required this.color});
}

/// All six colour options used in the game.
const kColorEntries = [
  ColorEntry(name: 'RED',    color: Color(0xFFEF4444)),
  ColorEntry(name: 'BLUE',   color: Color(0xFF3B82F6)),
  ColorEntry(name: 'GREEN',  color: Color(0xFF10B981)),
  ColorEntry(name: 'YELLOW', color: Color(0xFFFFD166)),
  ColorEntry(name: 'PURPLE', color: Color(0xFFA78BFA)),
  ColorEntry(name: 'ORANGE', color: Color(0xFFF97316)),
];

// ─────────────────────────────────────────────────────────────────────────────
// Round
// ─────────────────────────────────────────────────────────────────────────────

/// One question the player must answer.
class ColorMatchRound {
  /// The text rendered on screen (e.g. "RED").
  final String word;

  /// The colour the word is painted in — this is the correct answer.
  final ColorEntry inkColor;

  /// Four shuffled button options shown to the player.
  final List<ColorEntry> choices;

  const ColorMatchRound({
    required this.word,
    required this.inkColor,
    required this.choices,
  });

  /// True when the word text and ink colour are the same — easier to answer.
  bool get isCongruent => word == inkColor.name;
}

// ─────────────────────────────────────────────────────────────────────────────
// Game state
// ─────────────────────────────────────────────────────────────────────────────

class ColorMatchState {
  final ColorMatchPhase phase;
  final ColorMatchDifficulty difficulty;
  final int score;
  final int lives;
  final int streak;
  final int bestStreak;
  final int timeLeft;   // seconds remaining this game
  final int countdown;  // 3-2-1 before game starts
  final int mistakes;
  final int correct;    // total correct answers this game
  final ColorMatchRound? round;

  const ColorMatchState({
    required this.phase,
    required this.difficulty,
    required this.score,
    required this.lives,
    required this.streak,
    required this.bestStreak,
    required this.timeLeft,
    required this.countdown,
    required this.mistakes,
    required this.correct,
    this.round,
  });

  factory ColorMatchState.initial(ColorMatchDifficulty difficulty) =>
      ColorMatchState(
        phase:      ColorMatchPhase.idle,
        difficulty: difficulty,
        score:      0,
        lives:      3,
        streak:     0,
        bestStreak: 0,
        timeLeft:   timerForDifficulty(difficulty),
        countdown:  3,
        mistakes:   0,
        correct:    0,
      );

  // ── Helpers ────────────────────────────────────────────────────────────────

  static int timerForDifficulty(ColorMatchDifficulty d) {
    switch (d) {
      case ColorMatchDifficulty.easy:   return 60;
      case ColorMatchDifficulty.medium: return 45;
      case ColorMatchDifficulty.hard:   return 30;
    }
  }

  /// Total timer for this difficulty (used to compute progress bar fraction).
  int get totalTimer => timerForDifficulty(difficulty);

  /// Accuracy percentage [0–100].
  int get accuracy {
    final total = correct + mistakes;
    if (total == 0) return 0;
    return (correct / total * 100).round();
  }

  ColorMatchState copyWith({
    ColorMatchPhase?     phase,
    ColorMatchDifficulty? difficulty,
    int?                 score,
    int?                 lives,
    int?                 streak,
    int?                 bestStreak,
    int?                 timeLeft,
    int?                 countdown,
    int?                 mistakes,
    int?                 correct,
    ColorMatchRound?     round,
    bool                 clearRound = false,
  }) =>
      ColorMatchState(
        phase:      phase      ?? this.phase,
        difficulty: difficulty ?? this.difficulty,
        score:      score      ?? this.score,
        lives:      lives      ?? this.lives,
        streak:     streak     ?? this.streak,
        bestStreak: bestStreak ?? this.bestStreak,
        timeLeft:   timeLeft   ?? this.timeLeft,
        countdown:  countdown  ?? this.countdown,
        mistakes:   mistakes   ?? this.mistakes,
        correct:    correct    ?? this.correct,
        round:      clearRound ? null : (round ?? this.round),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Round generator
// ─────────────────────────────────────────────────────────────────────────────

ColorMatchRound generateRound(ColorMatchDifficulty difficulty) {
  final rng = Random();

  // Pick the word (semantic meaning).
  final wordEntry = kColorEntries[rng.nextInt(kColorEntries.length)];

  // Pick the ink colour (what the player must tap).
  late ColorEntry inkColor;
  if (difficulty == ColorMatchDifficulty.easy && rng.nextDouble() < 0.40) {
    // 40 % congruent on Easy — matching word and ink → easier
    inkColor = wordEntry;
  } else {
    // Medium / Hard: always incongruent (the Stroop conflict).
    final others = kColorEntries.where((c) => c.name != wordEntry.name).toList();
    inkColor = others[rng.nextInt(others.length)];
  }

  // Build 4 choices: the correct ink colour + 3 random distractors.
  final pool = List<ColorEntry>.from(kColorEntries)
    ..removeWhere((c) => c.name == inkColor.name)
    ..shuffle(rng);
  final choices = [inkColor, pool[0], pool[1], pool[2]]..shuffle(rng);

  return ColorMatchRound(
    word:     wordEntry.name,
    inkColor: inkColor,
    choices:  choices,
  );
}
