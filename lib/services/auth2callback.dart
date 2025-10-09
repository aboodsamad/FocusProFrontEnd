// import 'package:flutter/material.dart';
// import 'dart:html' as html;
// import '../services/loginservice.dart';
// import '../pages/homePage.dart';

// class OAuth2CallbackPage extends StatefulWidget {
//   const OAuth2CallbackPage({super.key});

//   @override
//   State<OAuth2CallbackPage> createState() => _OAuth2CallbackPageState();
// }

// class _OAuth2CallbackPageState extends State<OAuth2CallbackPage> {
//   @override
//   void initState() {
//     super.initState();
//     _processToken();
//   }

//   Future<void> _processToken() async {
//     final uri = Uri.parse(html.window.location.href);
//     final token = uri.queryParameters['token'];

//     print('=== OAUTH CALLBACK ===');
//     print('URL: ${html.window.location.href}');
//     print('Token: $token');

//     if (token != null && token.isNotEmpty) {
//       await ApiService.saveToken(token);
//       print('Token saved');

//       // Use a different navigation approach
//       await Future.delayed(Duration(milliseconds: 100));

//       if (mounted) {
//         // Use Navigator.pushReplacement instead
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(builder: (_) => const HomeScreen()),
//         );
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Center(
//         child: CircularProgressIndicator(),
//       ),
//     );
//   }
// }

import 'dart:convert';

import 'package:capstone_front_end/pages/homePage.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import './loginservice.dart';

class myTry extends StatefulWidget {
  const myTry({super.key});

  @override
  State<myTry> createState() => _myTryState();
}

class _myTryState extends State<myTry> {
  final _formerKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscured = true;
  bool _isloading = false;

  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> log(String username, String password) async {
    final url = Uri.parse('${ApiService.baseUrl}/user/login');
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

  Future<void> _login() async {
    if (!_formerKey.currentState!.validate()) return;
    setState(() {
      _isloading = true;
    });
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    print('Username: $username, Password: $password');
    try {
      final result = await ApiService.login(username, password);
      setState(() {
        _isloading = false;
      });
      final token = result['token']?.toString() ?? '';
      if (token.isNotEmpty) {
        await ApiService.saveToken(token);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
      }
    } catch (e) {
      print('Login error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}





