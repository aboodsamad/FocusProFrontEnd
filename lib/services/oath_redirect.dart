
import 'package:flutter/material.dart';
import '../services/loginservice.dart';
import 'dart:html' as html;


class OAuthCallbackPage extends StatefulWidget {
  @override
  _OAuthCallbackPageState createState() => _OAuthCallbackPageState();
}
class _OAuthCallbackPageState extends State<OAuthCallbackPage> {
  bool _hasHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasHandled) {
        _hasHandled = true;
        _handleCallback();
      }
    });
  }

void _handleCallback() async {
  try {
    final hashPart = html.window.location.hash;
    print('Hash part: $hashPart');

    String? token;
    if (hashPart.contains('token=')) {
      token = hashPart.split('token=')[1].split('&')[0];
    }
    print('Extracted token: $token');

    // If no token, go back to login
    if (token == null || token.isEmpty) {
      print('No token found in callback, redirecting to /');
      if (mounted) Navigator.of(context).pushReplacementNamed('/');
      return;
    }

    // Check if token already saved to avoid duplicate handling
    final existing = await ApiService.getToken();
    if (existing != null && existing == token) {
      print('Token already saved previously; clearing hash and navigating home.');
      // Remove hash from URL (more reliable)
      html.window.history.replaceState(null, '', '${html.window.location.pathname}${html.window.location.search}');
      if (mounted) Navigator.of(context).pushReplacementNamed('/home');
      return;
    }

    // Save token
    await ApiService.saveToken(token);
    print('Token saved successfully');

    // Remove hash from the URL so onGenerateRoute won't re-route to callback
    html.window.history.replaceState(null, '', '${html.window.location.pathname}${html.window.location.search}');
    print('Cleared hash with history.replaceState');

    // Now navigate to home
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  } catch (e, st) {
    print('Error handling oauth callback: $e');
    print(st);
    // fallback to login page on error
    if (mounted) Navigator.of(context).pushReplacementNamed('/');
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