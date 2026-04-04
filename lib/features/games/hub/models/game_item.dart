/// Represents a single game entry in the Games Hub.
/// Add new games by appending to [GameItem.all].

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────

enum GameCategory { memory, logic, speed, attention }

enum GameDifficulty { easy, medium, hard }

enum GameStatus { available, comingSoon }

// ─────────────────────────────────────────────────────────────────────────────
// GameItem
// ─────────────────────────────────────────────────────────────────────────────

class GameItem {
  final String       id;
  final String       title;
  final String       description;
  final String       shortDesc;   // one-liner shown on small card
  final GameCategory category;
  final GameDifficulty difficulty;
  final GameStatus   status;

  /// Hex color value — used in widgets for tinting.
  final int colorValue;

  /// Icon shown on the game card.
  final IconData icon;

  const GameItem({
    required this.id,
    required this.title,
    required this.description,
    required this.shortDesc,
    required this.category,
    required this.difficulty,
    required this.status,
    required this.colorValue,
    required this.icon,
  });

  // ── Derived string labels ──────────────────────────────────────────────────

  String get categoryLabel {
    switch (category) {
      case GameCategory.memory:    return 'Memory';
      case GameCategory.logic:     return 'Logic';
      case GameCategory.speed:     return 'Speed';
      case GameCategory.attention: return 'Attention';
    }
  }

  String get difficultyLabel {
    switch (difficulty) {
      case GameDifficulty.easy:   return 'Easy';
      case GameDifficulty.medium: return 'Medium';
      case GameDifficulty.hard:   return 'Hard';
    }
  }

  bool get isAvailable => status == GameStatus.available;
}
