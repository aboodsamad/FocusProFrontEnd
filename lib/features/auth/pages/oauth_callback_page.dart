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

  /// Pull `token=` out of any URL fragment/query string segment.
  String? _extractToken(String source) {
    if (!source.contains('token=')) return null;
    final raw = source.split('token=')[1].split('&')[0];
    if (raw.isEmpty) return null;
    return Uri.decodeComponent(raw);
  }

  void _handleCallback() async {
    try {
      final hashPart   = getLocationHash();
      final searchPart = getLocationSearch();
      print('OAuth callback — hash: $hashPart  search: $searchPart');

      // Try hash first, fall back to query string.
      final token = _extractToken(hashPart) ?? _extractToken(searchPart);
      print('Extracted token: $token');

      if (token == null || token.isEmpty) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/');
        return;
      }

      await AuthService.saveToken(token);
      // Clean the token out of the URL bar.
      replaceState(getLocationPathname());

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