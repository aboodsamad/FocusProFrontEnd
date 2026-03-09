import 'dart:convert';
import 'package:flutter/foundation.dart'
    show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_config.dart';

class AuthService {
  // Single source of truth for base URL across the whole app
  static String get baseUrl => kIsWeb
      ? '${AppConfig.baseUrl}'
      : 'http://10.0.2.2:8080';

  // ── Token storage ────────────────────────────────────────
  static Future<void> saveToken(
    String token,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<String?> getToken() async {
    final prefs =
        await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // ── Login ────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    final url = Uri.parse('$baseUrl/user/login');
    try {
      final resp = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'username': username,
              'password': password,
            }),
          )
          .timeout(Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final body = resp.body.trim();
        try {
          final decoded = jsonDecode(body);
          if (decoded is Map<String, dynamic>)
            return decoded;
        } catch (_) {
          return {'token': body};
        }
      }
      throw Exception(
        'Login failed: ${resp.statusCode}',
      );
    } catch (e) {
      throw Exception('Login error: $e');
    }
  }

  // ── Sign Up ──────────────────────────────────────────────
  static Future<Map<String, dynamic>> signup(
    Map<String, dynamic> signupData,
  ) async {
    final url = Uri.parse(
      '$baseUrl/user/register',
    );
    try {
      final resp = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(signupData),
          )
          .timeout(Duration(seconds: 10));

      if (resp.statusCode == 200 ||
          resp.statusCode == 201) {
        final body = resp.body.trim();
        try {
          final decoded = jsonDecode(body);
          if (decoded is Map<String, dynamic>)
            return decoded;
        } catch (_) {
          return {'message': body};
        }
      }
      throw Exception(
        'Signup failed: ${resp.statusCode} - ${resp.body}',
      );
    } catch (e) {
      throw Exception('Signup error: $e');
    }
  }
}
