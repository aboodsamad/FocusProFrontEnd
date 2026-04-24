import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/auth_service.dart';

/// Persists the highest unlocked level per game.
///
/// Strategy:
///   - SharedPreferences is the source of truth locally (fast, offline-safe).
///   - The backend upserts level progress automatically via POST /game/result.
///   - On [syncFromBackend] the remote values are merged in (takes the max).
class GameProgressService {
  GameProgressService._();

  static const String _prefix = 'game_level_';

  /// Games that use the level roadmap and how many levels they have.
  static const Map<String, int> _totalLevels = {
    'memory_matrix': 10,
    'number_stream': 10,
    'pattern_trail': 10,
    'train_of_thought': 5,
  };

  static bool hasRoadmap(String gameId) => _totalLevels.containsKey(gameId);

  static int totalLevels(String gameId) => _totalLevels[gameId] ?? 0;

  // ── Local persistence ────────────────────────────────────────────────────────

  /// Returns the highest level the player can start at (always ≥ 1).
  static Future<int> getMaxUnlockedLevel(String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_prefix$gameId') ?? 1;
  }

  /// Persists [level] locally if it exceeds the previous record.
  /// The backend is updated separately via the normal submitResult() call
  /// (which already includes levelReached in the request body).
  static Future<void> unlockUpToLevel(String gameId, int level) async {
    final prefs   = await SharedPreferences.getInstance();
    final current = prefs.getInt('$_prefix$gameId') ?? 1;
    final total   = _totalLevels[gameId] ?? 1;
    final clamped = level.clamp(1, total);

    if (clamped > current) {
      await prefs.setInt('$_prefix$gameId', clamped);
      

    }
  }

  // ── Backend sync ──────────────────────────────────────────────────────────────

  /// Called after a successful login / profile refresh to pull backend
  /// progress and merge locally.  Backend values win only when higher.
  static Future<void> syncFromBackend() async {
    final token = await AuthService.getToken();
    if (token == null) return;

    try {
      final resp = await http
          .get(
            Uri.parse('${AuthService.baseUrl}/game/progress'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode != 200) return;

      final List<dynamic> list = jsonDecode(resp.body) as List<dynamic>;
      final prefs = await SharedPreferences.getInstance();

      for (final item in list) {
        final gameType = item['gameType'] as String?;
        final remote   = (item['maxUnlockedLevel'] as num?)?.toInt() ?? 1;
        if (gameType == null || !_totalLevels.containsKey(gameType)) continue;

        final local  = prefs.getInt('$_prefix$gameType') ?? 1;
        if (remote > local) {
          await prefs.setInt('$_prefix$gameType', remote);
        }
      }
    } catch (_) {
      // Network unavailable – local progress is still usable
    }
  }
}
