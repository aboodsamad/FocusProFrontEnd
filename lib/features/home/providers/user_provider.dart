import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/long_term_score_service.dart';
import '../services/user_service.dart';
import '../../games/services/game_progress_service.dart';

class UserProvider extends ChangeNotifier {
  // ── State ──────────────────────────────────────────────────────────────────
  bool _isLoading = true;
  bool _isLoggedIn = false;

  String _name = '';
  String _username = '';
  String _email = '';
  String _dob = '';
  int? _userId;
  double _focusScore = 0.0;     // baseline from backend / diagnostic
  double _longTermScore = 0.0;  // EMA-calculated long-term score
  double? _weekTrend;           // change over past 7 days
  String _roleName = '';

  // ── Getters ────────────────────────────────────────────────────────────────
  bool get isLoading       => _isLoading;
  bool get isLoggedIn      => _isLoggedIn;
  String get name          => _name.isNotEmpty ? _name : 'User';
  String get username      => _username;
  String get email         => _email;
  String get dob           => _dob;
  int?   get userId        => _userId;
  double get focusScore    => _focusScore;
  double get longTermScore => _longTermScore;
  double? get weekTrend    => _weekTrend;
  String get roleName      => _roleName;

  String get displayInitial =>
      _name.isNotEmpty ? _name[0].toUpperCase() : 'U';
 
  // ── Boot: call this once from main() ──────────────────────────────────────
  Future<void> init() async {
    await _loadFromPrefs();
    _isLoading = false;
    notifyListeners();
    // Process any pending EMA days (runs after prefs are loaded)
    await _runLongTermUpdate();
    await _refreshFromApi();
  }

  // ── Load from local storage ────────────────────────────────────────────────
  Future<void> _loadFromPrefs() async {
    final token = await AuthService.getToken();
    _isLoggedIn = token != null;
    if (!_isLoggedIn) return;

    final prefs = await SharedPreferences.getInstance();
    _name       = prefs.getString('name')        ?? '';
    _username   = prefs.getString('username')    ?? '';
    _email      = prefs.getString('email')       ?? '';
    _dob        = prefs.getString('dob')         ?? '';
    _userId     = prefs.getInt('user_id');
    _focusScore = prefs.getDouble('focus_score') ?? 0.0;
    _roleName   = prefs.getString('role_name')   ?? '';

    // Load the EMA long-term score (may differ from backend focusScore)
    final ltScore = await LongTermScoreService.getScore();
    _longTermScore = ltScore ?? _focusScore;
    _weekTrend = await LongTermScoreService.getWeekTrend();
  }

  // ── Run long-term EMA update ───────────────────────────────────────────────
  Future<void> _runLongTermUpdate() async {
    if (!_isLoggedIn) return;
    final updated = await LongTermScoreService.processPendingDays();
    if (updated != null) {
      _longTermScore = updated;
      _weekTrend = await LongTermScoreService.getWeekTrend();
      notifyListeners();
    }
  }
 
  // ── Refresh from API ───────────────────────────────────────────────────────
  Future<void> _refreshFromApi() async {
    final token = await AuthService.getToken();
    if (token == null) return;
    final status = await UserService.fetchAndSaveProfile(token);
    if (status == 200) {
      await _loadFromPrefs();  // re-read updated values
      notifyListeners();       // widgets rebuild with fresh data
      // Sync level progress from backend (merge – local values are never overwritten
      // by lower remote values, so this is safe to call anytime).
      await GameProgressService.syncFromBackend();
    } else if (status == 401 || status == 403) {
      // Token is expired or invalid — log out so routing sends user to login
      await logout();
    }
    // null (network/timeout) or other status: keep current auth state
  }
 
  /// Call after login to trigger a fresh load.
  Future<void> reloadAfterLogin() async {
    _isLoading = true;
    notifyListeners();
    await _loadFromPrefs();
    await _runLongTermUpdate();
    await _refreshFromApi();
    _isLoading = false;
    notifyListeners();
  }

  /// Update diagnostic baseline score (called after diagnostic completion).
  /// Also seeds the long-term EMA tracker from this baseline.
  Future<void> updateFocusScore(double score) async {
    _focusScore = score;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('focus_score', score);
    // Seed long-term tracker if this is the first diagnostic
    await LongTermScoreService.seedFromDiagnostic(score);
    _longTermScore = (await LongTermScoreService.getScore()) ?? score;
    _weekTrend = await LongTermScoreService.getWeekTrend();
    notifyListeners();
  }

  /// Clear everything on logout.
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    // Preserve game-level progress so the roadmap survives logout/login.
    // syncFromBackend() on login will merge-in backend values (taking max),
    // so if the backend has a higher level it will still win.
    final Map<String, int> savedLevels = {};
    for (final key in prefs.getKeys()) {
      if (key.startsWith('game_level_')) {
        final val = prefs.getInt(key);
        if (val != null) savedLevels[key] = val;
      }
    }
    await prefs.clear();
    for (final entry in savedLevels.entries) {
      await prefs.setInt(entry.key, entry.value);
    }
    _isLoggedIn = false;
    _name = '';
    _username = '';
    _email = '';
    _focusScore = 0.0;
    _longTermScore = 0.0;
    _weekTrend = null;
    _userId = null;
    _roleName = '';
    notifyListeners();
  }
}
 