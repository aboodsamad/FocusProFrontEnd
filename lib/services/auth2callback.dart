import 'package:flutter/material.dart';
import 'dart:html' as html;
import '../services/loginservice.dart';
import '../pages/homePage.dart';

class OAuth2CallbackPage extends StatefulWidget {
  const OAuth2CallbackPage({super.key});

  @override
  State<OAuth2CallbackPage> createState() => _OAuth2CallbackPageState();
}

class _OAuth2CallbackPageState extends State<OAuth2CallbackPage> {
  @override
  void initState() {
    super.initState();
    _processToken();
  }

  Future<void> _processToken() async {
    final uri = Uri.parse(html.window.location.href);
    final token = uri.queryParameters['token'];
    
    print('=== OAUTH CALLBACK ===');
    print('URL: ${html.window.location.href}');
    print('Token: $token');

    if (token != null && token.isNotEmpty) {
      await ApiService.saveToken(token);
      print('Token saved');
      
      // Use a different navigation approach
      await Future.delayed(Duration(milliseconds: 100));
      
      if (mounted) {
        // Use Navigator.pushReplacement instead
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}