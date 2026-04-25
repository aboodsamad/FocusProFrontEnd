/// Pure-Dart model — no Flutter dependency.
/// Holds all game state for the Color Match (Stroop) game.

import 'dart:math';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────

enum ColorMatchPhase { idle, countdown, playing, levelComplete }

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

  bool get isCongruent => word == inkColor.name;
}

// ─────────────────────────────────────────────────────────────────────────────
// Game state
// ─────────────────────────────────────────────────────────────────────────────

class ColorMatchState {
  final ColorMatchPhase phase;
  final int level;
  final int score;
  final int streak;
  final int bestStreak;
  final int timeLeft;
  final int countdown;
  final int mistakes;
  final int correct;
  final ColorMatchRound? round;

  const ColorMatchState({
    required this.phase,
    required this.level,
    required this.score,
    required this.streak,
    required this.bestStreak,
    required this.timeLeft,
    required this.countdown,
    required this.mistakes,
    required this.correct,
    this.round,
  });

  factory ColorMatchState.initial(int level) => ColorMatchState(
    phase:      ColorMatchPhase.idle,
    level:      level,
    score:      0,
    streak:     0,
    bestStreak: 0,
    timeLeft:   timerForLevel(level),
    countdown:  3,
    mistakes:   0,
    correct:    0,
  );

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Session duration in seconds: 60s at level 1, decreasing by 3s per level, min 30s.
  static int timerForLevel(int level) =>
      (60 - (level - 1) * 3).clamp(30, 60);

  /// Fraction of rounds that are congruent (word == ink) — easier.
  /// Starts at 40 % at level 1 and drops to 0 % by level 11.
  static double congruencyRateForLevel(int level) =>
      (0.40 - (level - 1) * 0.04).clamp(0.0, 0.40);

  int get totalTimer => timerForLevel(level);

  int get accuracy {
    final total = correct + mistakes;
    if (total == 0) return 0;
    return (correct / total * 100).round();
  }

  ColorMatchState copyWith({
    ColorMatchPhase? phase,
    int?             level,
    int?             score,
    int?             streak,
    int?             bestStreak,
    int?             timeLeft,
    int?             countdown,
    int?             mistakes,
    int?             correct,
    ColorMatchRound? round,
    bool             clearRound = false,
  }) =>
      ColorMatchState(
        phase:      phase      ?? this.phase,
        level:      level      ?? this.level,
        score:      score      ?? this.score,
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

ColorMatchRound generateRound(int level) {
  final rng = Random();

  final wordEntry = kColorEntries[rng.nextInt(kColorEntries.length)];

  late ColorEntry inkColor;
  final congruencyRate = ColorMatchState.congruencyRateForLevel(level);
  if (congruencyRate > 0 && rng.nextDouble() < congruencyRate) {
    inkColor = wordEntry;
  } else {
    final others = kColorEntries.where((c) => c.name != wordEntry.name).toList();
    inkColor = others[rng.nextInt(others.length)];
  }

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
