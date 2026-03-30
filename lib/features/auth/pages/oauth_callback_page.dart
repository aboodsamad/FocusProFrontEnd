import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:capstone_front_end/core/utils/url_helper.dart';
import '../../../core/services/auth_service.dart';
import '../../../features/home/services/user_service.dart';
import '../../../features/home/providers/user_provider.dart';
import '../../../features/home/pages/home_page.dart';
import '../../../features/diagnostic/pages/diagnostic_page.dart';

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
      print('[OAuth] Token saved to SharedPreferences');
      // Clean the token out of the URL bar.
      replaceState(getLocationPathname());

      // Fetch profile to determine if this is a new user (no focus score yet).
      final profileStatus = await UserService.fetchAndSaveProfile(token);
      print('[OAuth] fetchAndSaveProfile status: $profileStatus');

      final profile = await UserService.getStoredProfile();
      print('[OAuth] Raw profile from storage: $profile');

      final rawFocusScore = profile?['focusScore'];
      print('[OAuth] raw focusScore field: $rawFocusScore (type: ${rawFocusScore?.runtimeType})');

      final focusScore = rawFocusScore != null ? double.tryParse(rawFocusScore.toString()) : null;
      print('[OAuth] parsed focusScore: $focusScore');

      final isNewUser = focusScore == null || focusScore == 0.0;
      print('[OAuth] isNewUser: $isNewUser → routing to ${isNewUser ? "DiagnosticPage" : "HomeScreen"}');

      if (!mounted) return;

      // Notify the provider so the rest of the app sees the user as logged in.
      await Provider.of<UserProvider>(context, listen: false).reloadAfterLogin();
      print('[OAuth] UserProvider reloaded, isLoggedIn: ${Provider.of<UserProvider>(context, listen: false).isLoggedIn}');

      if (!mounted) return;

      if (isNewUser) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => DiagnosticPage(token: token)),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e, st) {
      print('[OAuth] ERROR: $e');
      print('[OAuth] STACKTRACE: $st');
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