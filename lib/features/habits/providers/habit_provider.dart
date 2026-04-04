import 'package:flutter/foundation.dart';
import '../../../core/services/auth_service.dart';
import '../models/habit.dart';
import '../services/habit_service.dart';

class HabitProvider extends ChangeNotifier {
  List<Habit> _habits = [];
  bool _isLoading = false;
  String? _error;

  List<Habit> get habits => List.unmodifiable(_habits);
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get doneCount => _habits.where((h) => h.doneToday).length;
  int get totalCount => _habits.length;

  // ── Boot ──────────────────────────────────────────────────────────────────
  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final token = await AuthService.getToken() ?? '';
      _habits = await HabitService.getHabits(token);
    } catch (e) {
      _error = 'Could not load habits';
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Toggle done today ─────────────────────────────────────────────────────
  Future<void> toggle(Habit habit) async {
    final idx = _habits.indexOf(habit);
    if (idx < 0) return;

    // Optimistic update
    _habits[idx] = habit.copyWith(
      doneToday: !habit.doneToday,
      streak: !habit.doneToday
          ? habit.streak + 1
          : (habit.streak > 0 ? habit.streak - 1 : 0),
    );
    notifyListeners();

    try {
      final token = await AuthService.getToken() ?? '';
      final updated = await HabitService.toggleHabit(token, habit);
      _habits[idx] = updated;
      notifyListeners();
    } catch (_) {
      // Keep optimistic result
    }
  }

  // ── Add ───────────────────────────────────────────────────────────────────
  Future<void> add(Habit habit) async {
    try {
      final token = await AuthService.getToken() ?? '';
      final created = await HabitService.createHabit(token, habit);
      _habits.add(created);
      notifyListeners();
    } catch (e) {
      _error = 'Could not save habit';
      notifyListeners();
    }
  }

  // ── Edit ──────────────────────────────────────────────────────────────────
  Future<void> edit(Habit old, Habit updated) async {
    final idx = _habits.indexOf(old);
    if (idx < 0) return;

    _habits[idx] = updated;
    notifyListeners();

    try {
      final token = await AuthService.getToken() ?? '';
      final saved = await HabitService.updateHabit(token, updated);
      _habits[idx] = saved;
      notifyListeners();
    } catch (_) {}
  }

  // ── Delete ────────────────────────────────────────────────────────────────
  Future<void> delete(Habit habit) async {
    _habits.remove(habit);
    notifyListeners();

    try {
      final token = await AuthService.getToken() ?? '';
      await HabitService.deleteHabit(token, habit);
    } catch (_) {}
  }
}
