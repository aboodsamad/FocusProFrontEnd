import 'package:flutter/material.dart';

import 'game_item.dart';
import '../../memory_matrix/pages/memory_matrix_page.dart';
import '../../sudoku/pages/sudoku_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GameRegistry
// ─────────────────────────────────────────────────────────────────────────────

/// Single source of truth for every game in FocusPro.
/// To add a new game:
///   1. Append a [GameItem] to [all].
///   2. Add a matching case in [GameRegistry.pageFor].
///   That's it — the hub picks it up automatically.

class GameRegistry {
  GameRegistry._();

  // ── Game list ──────────────────────────────────────────────────────────────

  static const List<GameItem> all = [
    GameItem(
      id:            'memory_matrix',
      title:         'Memory Matrix',
      description:   'A grid lights up with a pattern — memorise it, then recreate it from memory. Patterns grow harder as you level up.',
      shortDesc:     'Memorise the grid pattern',
      category:      GameCategory.memory,
      difficulty:    GameDifficulty.medium,
      status:        GameStatus.available,
      colorValue:    0xFF7B6FFF,
      iconCodePoint: 0xe59e, // Icons.grid_on_rounded
    ),
    GameItem(
      id:            'sudoku',
      title:         'Sudoku',
      description:   'Fill every row, column and 3×3 box with the digits 1–9. No repeats allowed. Choose Easy, Medium or Hard.',
      shortDesc:     'Fill the grid with 1–9',
      category:      GameCategory.logic,
      difficulty:    GameDifficulty.hard,
      status:        GameStatus.available,
      colorValue:    0xFF6366F1,
      iconCodePoint: 0xe5c3, // Icons.apps_rounded
    ),
    GameItem(
      id:            'speed_match',
      title:         'Speed Match',
      description:   'Does the card on screen match the one before it? Tap Yes or No as fast as you can before the timer runs out.',
      shortDesc:     'Match cards at high speed',
      category:      GameCategory.speed,
      difficulty:    GameDifficulty.easy,
      status:        GameStatus.comingSoon,
      colorValue:    0xFFF59E0B,
      iconCodePoint: 0xe518, // Icons.bolt_rounded
    ),
    GameItem(
      id:            'color_match',
      title:         'Color Match',
      description:   'Tap the button whose color matches the meaning of the word — not the color the word is printed in. Classic Stroop effect.',
      shortDesc:     'Word vs ink color challenge',
      category:      GameCategory.attention,
      difficulty:    GameDifficulty.medium,
      status:        GameStatus.comingSoon,
      colorValue:    0xFF10B981,
      iconCodePoint: 0xe332, // Icons.palette_outlined
    ),
    GameItem(
      id:            'number_stream',
      title:         'Number Stream',
      description:   'Equations fall from the top of the screen. Solve them before they hit the bottom — speed and accuracy both count.',
      shortDesc:     'Solve falling equations',
      category:      GameCategory.speed,
      difficulty:    GameDifficulty.medium,
      status:        GameStatus.comingSoon,
      colorValue:    0xFFEC4899,
      iconCodePoint: 0xe3b4, // Icons.functions_rounded
    ),
    GameItem(
      id:            'pattern_trail',
      title:         'Pattern Trail',
      description:   'Dots appear one by one across the screen. Remember the sequence and tap them back in the exact same order.',
      shortDesc:     'Repeat the dot sequence',
      category:      GameCategory.memory,
      difficulty:    GameDifficulty.hard,
      status:        GameStatus.comingSoon,
      colorValue:    0xFF06B6D4,
      iconCodePoint: 0xe1ca, // Icons.timeline_rounded
    ),
  ];

  // ── Helpers ────────────────────────────────────────────────────────────────

  static List<GameItem> byCategory(GameCategory category) =>
      all.where((g) => g.category == category).toList();

  static List<GameItem> get available =>
      all.where((g) => g.isAvailable).toList();

  static GameItem? findById(String id) {
    try {
      return all.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Returns the Flutter [Widget] page for a given game id.
  /// Import all game pages here — one place to maintain.
  static Widget? pageFor(String id) {
    // Import game pages at the top of this file when you add them.
    // They are imported inside the switch to avoid circular deps.
    switch (id) {
      case 'memory_matrix':
        return const MemoryMatrixPage();
      case 'sudoku':
        return const SudokuHomePage();
      default:
        return null;
    }
  }
}