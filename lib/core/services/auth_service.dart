import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static String get baseUrl => kIsWeb
      ? 'http://localhost:8080'
      : 'http://localhost:8080';

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

  // ── Logout ─────────────────────────────────────────────────────────────────
  static Future<void> logout() async {
    try {
      final token = await getToken();
      if (token != null) {
        await http.post(
          Uri.parse('$baseUrl/user/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 5));
      }
    } catch (_) {}
    await clearToken(); // always clear locally regardless of server response
  }

  // ── Login ──────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
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
      throw Exception('Login error: $e');
    }
  }

  // ── Sign Up ────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> signup(
    Map<String, dynamic> signupData,
  ) async {
    await clearToken(); // clear any old token BEFORE signing up
    final url = Uri.parse('$baseUrl/user/register');
    try {
      final resp = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(signupData),
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        return _extractToken(resp.body);
      }
      throw Exception(_readError(resp));
    } catch (e) {
      throw Exception('Signup error: $e');
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
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        return decoded['message']?.toString() ??
            decoded['error']?.toString() ??
            body;
      }
    } catch (_) {}
    return body;
  }
}