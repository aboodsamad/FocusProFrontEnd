import 'package:flutter/material.dart';
import 'dart:html' as html;
import '../../../core/services/auth_service.dart';

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

      if (token == null || token.isEmpty) {
        print('No token found in callback, redirecting to /');
        if (mounted) Navigator.of(context).pushReplacementNamed('/');
        return;
      }

      final existing = await AuthService.getToken();
      if (existing != null && existing == token) {
        html.window.history.replaceState(
          null,
          '',
          '${html.window.location.pathname}${html.window.location.search}',
        );
        if (mounted) Navigator.of(context).pushReplacementNamed('/home');
        return;
      }

      await AuthService.saveToken(token);
      html.window.history.replaceState(
        null,
        '',
        '${html.window.location.pathname}${html.window.location.search}',
      );

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e, st) {
      print('Error handling oauth callback: $e');
      print(st);
      if (mounted) Navigator.of(context).pushReplacementNamed('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
