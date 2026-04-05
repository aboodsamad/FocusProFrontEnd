import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:capstone_front_end/core/utils/url_helper.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../features/home/services/user_service.dart';
import '../../../features/home/providers/user_provider.dart';
import '../../../features/home/pages/home_page.dart';
import '../../../features/diagnostic/pages/diagnostic_page.dart';
import '../widgets/complete_profile_dialog.dart';

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
      final hasConsented = profile?['consentUsage'] == true;
      print('[OAuth] isNewUser: $isNewUser, hasConsented: $hasConsented → routing to ${isNewUser ? "DiagnosticPage" : "HomeScreen"}');

      if (!mounted) return;

      // Notify the provider so the rest of the app sees the user as logged in.
      await Provider.of<UserProvider>(context, listen: false).reloadAfterLogin();
      print('[OAuth] UserProvider reloaded, isLoggedIn: ${Provider.of<UserProvider>(context, listen: false).isLoggedIn}');

      if (!mounted) return;

      // ── Complete-profile check (Google users with missing DOB) ────────────
      // dob is null when the user signed in with Google and hasn't filled it in yet.
      // We show the dialog every login until they do.
      final dobIsNull = profile?['dob'] == null;
      if (dobIsNull && mounted) {
        await showCompleteProfileDialog(context, token);
        if (!mounted) return;
      }

      if (isNewUser) {
        // Show consent only if this Google user hasn't consented yet.
        if (!hasConsented) {
          final consented = await _showConsentDialog();
          if (!mounted) return;
          if (consented == true) {
            await AuthService.activateConsent(token);
            print('[OAuth] Consent activated');
          }
        }
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

  Future<bool?> _showConsentDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryA, AppColors.primaryB],
                  ),
                ),
                child: const Icon(Icons.privacy_tip_outlined, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 20),
              const Text(
                'Data Usage Consent',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
              const SizedBox(height: 12),
              Text(
                'FocusPro collects focus-related data (session activity, diagnostic results, and usage patterns) to personalise your experience and improve the app.\n\nYour data is never sold and is handled in accordance with our privacy policy.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryA,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('I Agree', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('Decline', style: TextStyle(color: Colors.grey[500])),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}