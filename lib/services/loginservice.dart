// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // adjust for your environment:
  static const String baseUrl = 'http://localhost:8080';
  // static const String baseUrl = 'http://192.168.1.42:8080'; // real device example

  // Ping server (GET) to check connectivity quickly
  static Future<void> pingServer() async {
    final url = Uri.parse('$baseUrl/');
    print('PING -> $url');
    try {
      final resp = await http.post(url).timeout(Duration(seconds: 4));
      print('PING RESPONSE: status=${resp.statusCode} body=${resp.body}');
    } on TimeoutException catch (e, st) {
      print('PING TimeoutException: $e');
      print(st);
      rethrow;
    } on SocketException catch (e, st) {
      print('PING SocketException: $e');
      print(st);
      rethrow;
    } catch (e, st) {
      print('PING unknown error: $e');
      print(st);
      rethrow;
    }
  }

  // Login with defensive timeout and verbose errors
  static Future<Map<String, dynamic>> login(String username, String password) async {
    final url = Uri.parse('$baseUrl/user/login');

    print('=== API LOGIN REQUEST ===');
    print('URL: $url');
    print('Method: POST');
    final bodyJson = jsonEncode({'username': username, 'password': password});
    print('Request body JSON: $bodyJson');
    print('-------------------------');

    http.Response resp;
    try {
      // put a reasonable timeout so app doesn't hang forever
      resp = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: bodyJson,
          )
          .timeout(Duration(seconds: 8));
    } on TimeoutException catch (e, st) {
      print('HTTP POST TimeoutException -> $e');
      print(st);
      throw Exception('Request timed out (frontend). Is backend reachable?');
    } on SocketException catch (e, st) {
      print('HTTP POST SocketException -> $e');
      print(st);
      throw Exception('Connection error (SocketException). Check baseUrl and whether backend is running.');
    } catch (e, st) {
      print('HTTP POST unknown exception -> $e');
      print(st);
      throw Exception('Unexpected error sending request: $e');
    }

    print('=== API LOGIN RESPONSE ===');
    print('Status code: ${resp.statusCode}');
    print('Headers: ${resp.headers}');
    print('Body raw: <<<${resp.body}>>>');
    print('--------------------------');

    if (resp.statusCode == 200) {
      final body = resp.body;
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('token')) return {'token': decoded['token']?.toString() ?? ''};
          if (decoded.containsKey('access_token')) return {'token': decoded['access_token']?.toString() ?? ''};
          return decoded;
        } else if (decoded is String) {
          return {'token': decoded};
        } else {
          return {'token': decoded.toString()};
        }
      } catch (e) {
        // not JSON -> assume raw string token
        final token = body.trim();
        if (token.isNotEmpty) return {'token': token};
        throw Exception('Empty or invalid token received from server');
      }
    } else {
      String msg = 'Login failed: status ${resp.statusCode}';
      try {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map && decoded['error'] != null) msg = decoded['error'].toString();
        else if (decoded is String) msg = decoded;
        else msg = resp.body;
      } catch (_) {
        if (resp.body.isNotEmpty) msg = resp.body;
      }
      print('Login error parsed msg: $msg');
      throw Exception(msg);
    }
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    print('Saved token length=${token.length} to SharedPreferences');
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    print('Loaded token from SharedPreferences: ${token != null ? "(non-empty length=${token.length})" : "(null)"}');
    return token;
  }
}
