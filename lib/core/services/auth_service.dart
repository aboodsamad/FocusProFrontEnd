import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static String get baseUrl => kIsWeb ? 'https://focusprobackend.onrender.com' : 'https://focusprobackend.onrender.com';

  // ── Token storage ──────────────────────────────────────────────────────────
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // ── Consent ───────────────────────────────────────────────────────────────
  static Future<void> activateConsent(String token) async {
    final url = Uri.parse('$baseUrl/user/update-profile');
    print('[Consent] Calling PUT $url');
    print('[Consent] Token (first 30 chars): ${token.length > 30 ? token.substring(0, 30) : token}...');
    try {
      final resp = await http
          .put(url, headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 8));
      print('[Consent] Response status: ${resp.statusCode}');
      print('[Consent] Response body: ${resp.body}');
    } catch (e) {
      print('[Consent] ERROR: $e');
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  static Future<void> logout() async {
    try {
      final token = await getToken();
      if (token != null) {
        await http
            .post(
              Uri.parse('$baseUrl/user/logout'),
              headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
            )
            .timeout(const Duration(seconds: 5));
      }
    } catch (_) {}
    await clearToken(); // always clear locally regardless of server response
  }

  // ── Login ──────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(String username, String password) async {
    await clearToken(); // clear any old token BEFORE logging in
    final url = Uri.parse('$baseUrl/user/login');
    try {
      final resp = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'password': password}),
          )
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        return _extractToken(resp.body);
      }
      throw Exception(_readError(resp));
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('$e');
    }
  }

  // ── Sign Up ────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> signup(Map<String, dynamic> signupData) async {
    await clearToken(); // clear any old token BEFORE signing up
    final url = Uri.parse('$baseUrl/user/register');
    try {
      final resp = await http
          .post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode(signupData))
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        return _extractToken(resp.body);
      }
      throw Exception(_readError(resp));
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('$e');
    }
  }

  // ── Sign-up pre-validation ─────────────────────────────────────────────────
  static Future<void> validateSignup(String username, String email) async {
    final url = Uri.parse('$baseUrl/user/validate-signup');
    try {
      final resp = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'email': email}),
          )
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) return;
      throw Exception(_readError(resp));
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('$e');
    }
  }

  // ── Forgot Password ────────────────────────────────────────────────────────
  static Future<void> forgotPasswordSendOtp(String username, String email) async {
    final url = Uri.parse('$baseUrl/user/forgot-password');
    try {
      final resp = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'email': email}),
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) return;
      throw Exception(_readError(resp));
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('$e');
    }
  }

  static Future<void> resetPassword(String email, String newPassword) async {
    final url = Uri.parse('$baseUrl/user/reset-password');
    try {
      final resp = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'newPassword': newPassword}),
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) return;
      throw Exception(_readError(resp));
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('$e');
    }
  }

  // ── OTP ───────────────────────────────────────────────────────────────────
  static Future<void> sendOtp(String email) async {
    final url = Uri.parse('$baseUrl/user/send-otp');
    try {
      final resp = await http
          .post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'email': email}))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) return;
      throw Exception(_readError(resp));
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to send OTP: $e');
    }
  }

  static Future<void> verifyOtp(String email, String otp) async {
    final url = Uri.parse('$baseUrl/user/verify-otp');
    try {
      final resp = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'otp': otp}),
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) return;
      throw Exception(_readError(resp));
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to verify OTP: $e');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  static Map<String, dynamic> _extractToken(String body) {
    final raw = body.trim();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('token')) return decoded;
        if (decoded.containsKey('accessToken')) {
          return {'token': decoded['accessToken']};
        }
        return decoded;
      }
      if (decoded is String) return {'token': decoded};
    } catch (_) {}
    return {'token': raw};
  }

  static String _readError(http.Response resp) {
    final body = resp.body.trim();
    if (body.isEmpty) return 'Request failed (${resp.statusCode})';

    String raw = body;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        raw = decoded['message']?.toString() ?? decoded['error']?.toString() ?? body;
      }
    } catch (_) {}

    if (raw.isNotEmpty) return raw;
    if (resp.statusCode >= 500) return 'Something went wrong on our end. Please try again later.';
    return 'Request failed (${resp.statusCode})';
  }
}
