import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/auth_service.dart';

class UserService {
  // ── Fetch profile from API and save locally ──────────────
  static Future<bool> fetchAndSaveProfile(String token) async {
    final url = Uri.parse('${AuthService.baseUrl}/user/profile');
    try {
      final resp = await http
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(Duration(seconds: 8));

      if (resp.statusCode != 200) return false;

      final Map<String, dynamic> profile = jsonDecode(resp.body);
      final prefs = await SharedPreferences.getInstance();

      if (profile['id'] != null) {
        prefs.setInt('user_id', int.parse(profile['id'].toString()));
      }
      if (profile['username'] != null) {
        prefs.setString('username', profile['username'].toString());
      }
      if (profile['email'] != null) {
        prefs.setString('email', profile['email'].toString());
      }
      if (profile['name'] != null) {
        prefs.setString('name', profile['name'].toString());
      }
      if (profile['dob'] != null) {
        prefs.setString('dob', profile['dob'].toString());
      }
      if (profile['focusScore'] != null) {
        prefs.setDouble(
          'focus_score',
          double.parse(profile['focusScore'].toString()),
        );
      }

      final roleName = profile['role'] is Map
          ? profile['role']['name']?.toString()
          : null;
      if (roleName != null) prefs.setString('role_name', roleName);
      if (profile['authorities'] != null) {
        prefs.setString('authorities', jsonEncode(profile['authorities']));
      }

      prefs.setString('profile_json', jsonEncode(profile));
      return true;
    } catch (e) {
      print('fetchAndSaveProfile error: $e');
      return false;
    }
  }

  // ── Read stored profile ──────────────────────────────────
  static Future<Map<String, dynamic>?> getStoredProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('profile_json');
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── Individual field getters ─────────────────────────────
  static Future<int?> getStoredUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id');
  }

  static Future<String?> getStoredUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('username');
  }

  static Future<String?> getStoredEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('email');
  }

  static Future<String?> getStoredName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('name');
  }

  static Future<String?> getStoredDob() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('dob');
  }

  static Future<double?> getStoredFocusScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('focus_score');
  }

  static Future<String?> getStoredRoleName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('role_name');
  }

  static Future<List<dynamic>> getStoredAuthorities() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('authorities');
    if (raw == null) return [];
    try {
      return jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return [];
    }
  }
}
