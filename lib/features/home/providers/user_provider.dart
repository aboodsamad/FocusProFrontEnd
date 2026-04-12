import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/auth_service.dart';
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
  double _focusScore = 0.0;
  String _roleName = '';
 
  // ── Getters ────────────────────────────────────────────────────────────────
  bool get isLoading   => _isLoading;
  bool get isLoggedIn  => _isLoggedIn;
  String get name      => _name.isNotEmpty ? _name : 'User';
  String get username  => _username;
  String get email     => _email;
  String get dob       => _dob;
  int?   get userId    => _userId;
  double get focusScore => _focusScore;
  String get roleName  => _roleName;
 
  String get displayInitial =>
      _name.isNotEmpty ? _name[0].toUpperCase() : 'U';
 
  // ── Boot: call this once from main() ──────────────────────────────────────
  /// Loads from SharedPreferences immediately (instant),
  /// then refreshes from the API in the background.
  Future<void> init() async {
    await _loadFromPrefs();        // instant — no network
    _isLoading = false;
    notifyListeners();
    await _refreshFromApi();       // background refresh
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
      GameProgressService.syncFromBackend();
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
    await _refreshFromApi();
    _isLoading = false;
    notifyListeners();
  }
 
  /// Update focus score locally (e.g. after a diagnostic).
  void updateFocusScore(double score) {
    _focusScore = score;
    notifyListeners();
    // Also persist so it survives restart
    SharedPreferences.getInstance().then(
      (p) => p.setDouble('focus_score', score),
    );
  }
 
  /// Clear everything on logout.
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _isLoggedIn = false;
    _name = '';
    _username = '';
    _email = '';
    _focusScore = 0.0;
    _userId = null;
    _roleName = '';
    notifyListeners();
  }
}
 