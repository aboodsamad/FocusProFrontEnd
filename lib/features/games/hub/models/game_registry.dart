import 'package:flutter/material.dart';

import 'game_item.dart';
import '../../memory_matrix/pages/memory_matrix_page.dart';
import '../../sudoku/pages/sudoku_page.dart';
import '../../number_stream/pages/number_stream_page.dart';
import '../../train_of_thought/pages/train_of_thought_page.dart';
import '../../color_match/pages/color_match_page.dart';
import '../../speed_match/pages/speed_match_page.dart';
import '../../pattern_trail/pages/pattern_trail_page.dart';
import '../../services/game_progress_service.dart';

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
      id:         'memory_matrix',
      title:      'Memory Matrix',
      description:'A grid lights up with a pattern — memorise it, then recreate it from memory. Patterns grow harder as you level up.',
      shortDesc:  'Memorise the grid pattern',
      category:   GameCategory.memory,
      difficulty: GameDifficulty.medium,
      status:     GameStatus.available,
      colorValue: 0xFF7B6FFF,
      icon:       Icons.grid_on_rounded,
      imageUrl:   'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2a/FloorGoban.JPG/500px-FloorGoban.JPG',
    ),
    GameItem(
      id:         'sudoku',
      title:      'Sudoku',
      description:'Fill every row, column and 3×3 box with the digits 1–9. No repeats allowed. Choose Easy, Medium or Hard.',
      shortDesc:  'Fill the grid with 1–9',
      category:   GameCategory.logic,
      difficulty: GameDifficulty.hard,
      status:     GameStatus.available,
      colorValue: 0xFF6366F1,
      icon:       Icons.apps_rounded,
      imageUrl:   'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e0/Sudoku_Puzzle_by_L2G-20050714_standardized_layout.svg/500px-Sudoku_Puzzle_by_L2G-20050714_standardized_layout.svg.png',
    ),
    GameItem(
      id:         'speed_match',
      title:      'Speed Match',
      description:'Does the card on screen match the one before it? Tap Yes or No as fast as you can before the timer runs out.',
      shortDesc:  'Match cards at high speed',
      category:   GameCategory.speed,
      difficulty: GameDifficulty.easy,
      status:     GameStatus.available,
      colorValue: 0xFFF59E0B,
      icon:       Icons.bolt_rounded,
      imageUrl:   'https://upload.wikimedia.org/wikipedia/commons/thumb/5/58/AcetoFive.JPG/500px-AcetoFive.JPG',
    ),
    GameItem(
      id:         'color_match',
      title:      'Color Match',
      description:'Tap the button whose color matches the meaning of the word — not the color the word is printed in. Classic Stroop effect.',
      shortDesc:  'Word vs ink color challenge',
      category:   GameCategory.attention,
      difficulty: GameDifficulty.medium,
      status:     GameStatus.available,
      colorValue: 0xFF10B981,
      icon:       Icons.palette_outlined,
      imageUrl:   'https://upload.wikimedia.org/wikipedia/commons/thumb/f/fc/Stroop_stimuli_example.png/500px-Stroop_stimuli_example.png',
    ),
    GameItem(
      id:         'number_stream',
      title:      'Number Stream',
      description:'Equations fall from the top of the screen. Solve them before they hit the bottom — speed and accuracy both count.',
      shortDesc:  'Solve falling equations',
      category:   GameCategory.speed,
      difficulty: GameDifficulty.medium,
      status:     GameStatus.available,
      colorValue: 0xFFEC4899,
      icon:       Icons.functions_rounded,
      imageUrl:   'https://upload.wikimedia.org/wikipedia/commons/thumb/4/45/Arithmetic_operations.svg/500px-Arithmetic_operations.svg.png',
    ),
    GameItem(
      id:         'pattern_trail',
      title:      'Pattern Trail',
      description:'Dots appear one by one across the screen. Remember the sequence and tap them back in the exact same order.',
      shortDesc:  'Repeat the dot sequence',
      category:   GameCategory.memory,
      difficulty: GameDifficulty.hard,
      status:     GameStatus.available,
      colorValue: 0xFF378ADD,
      icon:       Icons.timeline_rounded,
      imageUrl:   'https://upload.wikimedia.org/wikipedia/commons/thumb/7/70/Corsiblock.png/500px-Corsiblock.png',
    ),
    GameItem(
      id:         'train_of_thought',
      title:      'Train of Thought',
      description:'Trains speed toward stations — tap junctions to switch the tracks and route each train to its matching colored station before it crashes.',
      shortDesc:  'Route trains to their stations',
      category:   GameCategory.attention,
      difficulty: GameDifficulty.medium,
      status:     GameStatus.available,
      colorValue: 0xFF5B8FFF,
      icon:       Icons.train_rounded,
      imageUrl:   'https://upload.wikimedia.org/wikipedia/commons/d/da/Railway_turnout_-_Oulu_Finland.jpg',
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
    switch (id) {
      case 'memory_matrix':
        return const MemoryMatrixPage();
      case 'sudoku':
        return const SudokuHomePage();
      case 'number_stream':
        return const NumberStreamPage();
      case 'train_of_thought':
        return const TrainOfThoughtPage();
      case 'color_match':
        return const ColorMatchPage();
      case 'speed_match':
        return const SpeedMatchPage();
      case 'pattern_trail':
        return const PatternTrailPage();
      default:
        return null;
    }
  }

  /// Returns a game page that starts at [startLevel].
  /// Only valid for games that have a level roadmap.
  static Widget? levelPageFor(String id, int startLevel) {
    switch (id) {
      case 'memory_matrix':
        return MemoryMatrixPage(startLevel: startLevel);
      case 'number_stream':
        return NumberStreamPage(startLevel: startLevel);
      case 'train_of_thought':
        return TrainOfThoughtPage(startLevel: startLevel);
      case 'pattern_trail':
        return PatternTrailPage(startLevel: startLevel);
      default:
        return null;
    }
  }

  /// True for games that use the level roadmap.
  static bool hasRoadmap(String id) => GameProgressService.hasRoadmap(id);

  /// Total levels for roadmap games.
  static int totalLevels(String id) => GameProgressService.totalLevels(id);
}