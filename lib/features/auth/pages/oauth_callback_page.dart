import 'package:flutter/material.dart';
import 'package:capstone_front_end/core/utils/url_helper.dart';
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
      final hashPart = getLocationHash(); 
      print('Hash part: $hashPart');

      String? token;
      if (hashPart.contains('token=')) {
        token = hashPart.split('token=')[1].split('&')[0];
      }
      print('Extracted token: $token');

      if (token == null || token.isEmpty) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/');
        return;
      }

      final existing = await AuthService.getToken();
      if (existing != null && existing == token) {
        replaceState(                        // ← replaced
          '${getLocationPathname()}${getLocationSearch()}',
        );
        if (mounted) Navigator.of(context).pushReplacementNamed('/home');
        return;
      }

      await AuthService.saveToken(token);
      replaceState(                          // ← replaced
        '${getLocationPathname()}${getLocationSearch()}',
      );

      if (mounted) Navigator.of(context).pushReplacementNamed('/home');

    } catch (e, st) {
      print('Error handling oauth callback: $e');
      print(st);
      if (mounted) Navigator.of(context).pushReplacementNamed('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}