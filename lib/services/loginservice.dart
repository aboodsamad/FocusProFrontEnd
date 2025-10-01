import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiService {
  // Use localhost for web, 10.0.2.2 for Android emulator
  static String get baseUrl =>
      kIsWeb ? 'http://localhost:8080' : 'http://10.0.2.2:8080';

  // Exchange OAuth code for JWT token
  static Future<String?> exchangeOAuthCode(String code) async {
    try {
      print('Exchanging code: $code');
      final response = await http
          .get(Uri.parse('$baseUrl/oauth/exchange/$code'))
          .timeout(Duration(seconds: 10));

      print('Exchange response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['token'];
      }
      return null;
    } catch (e) {
      print('Exchange error: $e');
      return null;
    }
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    print('Token saved successfully');
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    final url = Uri.parse('$baseUrl/user/login');

    try {
      final resp = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'password': password}),
          )
          .timeout(Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final body = resp.body.trim();
        try {
          final decoded = jsonDecode(body);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
        } catch (_) {
          return {'token': body};
        }
      }
      throw Exception('Login failed: ${resp.statusCode}');
    } catch (e) {
      throw Exception('Login error: $e');
    }
  }

  // Add this method to your ApiService class
  static Future<Map<String, dynamic>> signup(
    Map<String, dynamic> signupData,
  ) async {
    final url = Uri.parse('$baseUrl/user/register');

    try {
      final resp = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(signupData),
          )
          .timeout(Duration(seconds: 10));

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final body = resp.body.trim();
        try {
          final decoded = jsonDecode(body);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
        } catch (_) {
          return {'message': body};
        }
      }
      throw Exception('Signup failed: ${resp.statusCode} - ${resp.body}');
    } catch (e) {
      throw Exception('Signup error: $e');
    }
  }
}
