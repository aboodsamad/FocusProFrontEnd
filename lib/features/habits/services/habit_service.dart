import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/auth_service.dart';
import '../models/habit.dart';

/// Tries the backend API first; falls back to SharedPreferences when
/// the server is unreachable (offline / dev without backend).
class HabitService {
  static const String _prefsKey = 'local_habits';
  static String get _baseHabits => '${AuthService.baseUrl}/habits';

  // ── GET all habits ────────────────────────────────────────────────────────
  static Future<List<Habit>> getHabits(String token) async {
    try {
      final resp = await http
          .get(
            Uri.parse(_baseHabits),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 6));

      if (resp.statusCode == 200) {
        final List<dynamic> data = jsonDecode(resp.body);
        final habits = data.map((e) => Habit.fromJson(e as Map<String, dynamic>)).toList();
        await _saveLocally(habits);
        return habits;
      }
    } catch (_) {}
    // Fallback: local storage
    return _loadLocally();
  }

  // ── CREATE habit ─────────────────────────────────────────────────────────
  static Future<Habit> createHabit(String token, Habit habit) async {
    try {
      final resp = await http
          .post(
            Uri.parse(_baseHabits),
            headers: _headers(token),
            body: jsonEncode(habit.toJson()),
          )
          .timeout(const Duration(seconds: 6));

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final created = Habit.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
        await _upsertLocally(created);
        return created;
      }
    } catch (_) {}
    // Offline: give a local negative ID as temp id
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
              body: jsonEncode(habit.toJson()),
            )
            .timeout(const Duration(seconds: 6));

        if (resp.statusCode == 200) {
          final updated = Habit.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
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

  // ── TOGGLE done today ─────────────────────────────────────────────────────
  static Future<Habit> toggleHabit(String token, Habit habit) async {
    final toggled = habit.copyWith(
      doneToday: !habit.doneToday,
      streak: !habit.doneToday ? habit.streak + 1 : (habit.streak > 0 ? habit.streak - 1 : 0),
    );

    if (habit.id != null && habit.id! > 0) {
      try {
        final resp = await http
            .post(
              Uri.parse('$_baseHabits/${habit.id}/complete'),
              headers: _headers(token),
              body: jsonEncode({'doneToday': toggled.doneToday}),
            )
            .timeout(const Duration(seconds: 6));

        if (resp.statusCode == 200) {
          final updated = Habit.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
          await _upsertLocally(updated);
          return updated;
        }
      } catch (_) {}
    }
    await _upsertLocally(toggled);
    return toggled;
  }

  // ── Local storage helpers ─────────────────────────────────────────────────
  static Future<List<Habit>> _loadLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return _defaultHabits();
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Habit.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return _defaultHabits();
    }
  }

  static Future<void> _saveLocally(List<Habit> habits) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(habits.map((h) => h.toJson()).toList()));
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
    habits.removeWhere((h) => h.id == habit.id || h.title == habit.title);
    await _saveLocally(habits);
  }

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  // ── Default starter habits (first launch) ────────────────────────────────
  static List<Habit> _defaultHabits() => [
        const Habit(id: -1, title: 'Morning 10-min reading',   iconName: 'menu_book',  streak: 3, category: 'learning'),
        const Habit(id: -2, title: 'Daily reaction game',       iconName: 'videogame',  streak: 1, category: 'focus'),
        const Habit(id: -3, title: 'No social before 9 AM',     iconName: 'no_phone',   streak: 7, category: 'digital'),
      ];
}
