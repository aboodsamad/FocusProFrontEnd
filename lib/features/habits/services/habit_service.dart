import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/auth_service.dart';
import '../models/habit.dart';

/// Tries the backend API first; falls back to SharedPreferences when
/// the server is unreachable (offline / dev without backend).
///
/// Backend tables:
///   habits      – id, user_id, title, description, duration_minutes,
///                 frequency_per_week, monday…sunday, created_at, updated_at
///   habit_logs  – id, habit_id, user_id, logged_date, completed,
///                 time_spent_minutes, logged_at
///
/// API contract expected from Spring Boot:
///   GET    /habits          → list (doneToday & streak computed from logs)
///   POST   /habits          → create  (body: toApiJson)
///   PUT    /habits/{id}     → update  (body: toApiJson)
///   DELETE /habits/{id}
///   POST   /habits/{id}/log → upsert today's habit_log
///                             body: { "completed": bool, "timeSpentMinutes": int }
class HabitService {
  static const String _prefsKey = 'local_habits';
  static String get _baseHabits => '${AuthService.baseUrl}/habits';

  // ── GET all habits ────────────────────────────────────────────────────────
  static Future<List<Habit>> getHabits(String token) async {
    try {
      final resp = await http
          .get(Uri.parse(_baseHabits), headers: _headers(token))
          .timeout(const Duration(seconds: 6));

      if (resp.statusCode == 200) {
        final List<dynamic> data = jsonDecode(resp.body);
        final serverHabits =
            data.map((e) => Habit.fromJson(e as Map<String, dynamic>)).toList();
        // Merge local UI prefs (iconName, category) into server habits
        final merged = await _mergeLocalUiPrefs(serverHabits);
        await _saveLocally(merged);
        return merged;
      }
    } catch (_) {}
    return _loadLocally();
  }

  // ── CREATE habit ─────────────────────────────────────────────────────────
  static Future<Habit> createHabit(String token, Habit habit) async {
    try {
      final resp = await http
          .post(
            Uri.parse(_baseHabits),
            headers: _headers(token),
            body: jsonEncode(habit.toApiJson()),
          )
          .timeout(const Duration(seconds: 6));

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        // Backend returns the created habit; merge iconName/category from local
        final raw = Habit.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
        final created = raw.copyWith(
          iconName: habit.iconName,
          category: habit.category,
        );
        await _upsertLocally(created);
        return created;
      }
    } catch (_) {}
    // Offline fallback: negative temp ID
    final local = habit.copyWith(id: -(DateTime.now().millisecondsSinceEpoch));
    await _upsertLocally(local);
    return local;
  }

  // ── UPDATE habit ─────────────────────────────────────────────────────────
  static Future<Habit> updateHabit(String token, Habit habit) async {
    if (habit.id != null && habit.id! > 0) {
      try {
        final resp = await http
            .put(
              Uri.parse('$_baseHabits/${habit.id}'),
              headers: _headers(token),
              body: jsonEncode(habit.toApiJson()),
            )
            .timeout(const Duration(seconds: 6));

        if (resp.statusCode == 200) {
          final raw =
              Habit.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
          final updated = raw.copyWith(
            iconName: habit.iconName,
            category: habit.category,
          );
          await _upsertLocally(updated);
          return updated;
        }
      } catch (_) {}
    }
    await _upsertLocally(habit);
    return habit;
  }

  // ── DELETE habit ─────────────────────────────────────────────────────────
  static Future<void> deleteHabit(String token, Habit habit) async {
    if (habit.id != null && habit.id! > 0) {
      try {
        await http
            .delete(
              Uri.parse('$_baseHabits/${habit.id}'),
              headers: _headers(token),
            )
            .timeout(const Duration(seconds: 6));
      } catch (_) {}
    }
    await _removeLocally(habit);
  }

  // ── LOG / TOGGLE done today ───────────────────────────────────────────────
  /// POSTs to POST /habits/{id}/log which upserts a row in habit_logs for today.
  /// Returns the habit with doneToday toggled (optimistic; server value used if available).
  static Future<Habit> logHabit(String token, Habit habit) async {
    final nowDone = !habit.doneToday;

    if (habit.id != null && habit.id! > 0) {
      try {
        final resp = await http
            .post(
              Uri.parse('$_baseHabits/${habit.id}/log'),
              headers: _headers(token),
              body: jsonEncode({
                'completed': nowDone,
                'timeSpentMinutes': habit.durationMinutes,
              }),
            )
            .timeout(const Duration(seconds: 6));

        if (resp.statusCode == 200 || resp.statusCode == 201) {
          // Backend may return the updated habit or just the log entry
          try {
            final body = jsonDecode(resp.body) as Map<String, dynamic>;
            // If the response looks like a habit (has 'title'), use it
            if (body.containsKey('title')) {
              final updated = Habit.fromJson(body).copyWith(
                iconName: habit.iconName,
                category: habit.category,
              );
              await _upsertLocally(updated);
              return updated;
            }
          } catch (_) {}
          // Response was log entry or empty — use optimistic result
        }
      } catch (_) {}
    }

    // Offline / non-habit response: optimistic update
    final toggled = habit.copyWith(
      doneToday: nowDone,
      streak: nowDone
          ? habit.streak + 1
          : (habit.streak > 0 ? habit.streak - 1 : 0),
    );
    await _upsertLocally(toggled);
    return toggled;
  }

  // ── Local storage helpers ─────────────────────────────────────────────────
  static Future<List<Habit>> _loadLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Habit.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveLocally(List<Habit> habits) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefsKey, jsonEncode(habits.map((h) => h.toJson()).toList()));
  }

  static Future<void> _upsertLocally(Habit habit) async {
    final habits = await _loadLocally();
    final idx = habits.indexWhere((h) => h.id == habit.id);
    if (idx >= 0) {
      habits[idx] = habit;
    } else {
      habits.add(habit);
    }
    await _saveLocally(habits);
  }

  static Future<void> _removeLocally(Habit habit) async {
    final habits = await _loadLocally();
    habits.removeWhere((h) => h.id == habit.id);
    await _saveLocally(habits);
  }

  /// Merges locally-stored iconName/category into freshly-fetched server habits.
  static Future<List<Habit>> _mergeLocalUiPrefs(List<Habit> serverHabits) async {
    final local = await _loadLocally();
    return serverHabits.map((sh) {
      final cached = local.cast<Habit?>().firstWhere(
            (l) => l?.id == sh.id,
            orElse: () => null,
          );
      if (cached == null) return sh;
      return sh.copyWith(
        iconName: cached.iconName,
        category: cached.category,
      );
    }).toList();
  }

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
}
