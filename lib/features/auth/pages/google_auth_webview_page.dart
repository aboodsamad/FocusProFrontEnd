import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/providers/daily_score_provider.dart';
import '../../home/providers/user_provider.dart';
import '../../habits/providers/habit_provider.dart';
import '../../home/pages/home_page.dart';
import '../../home/services/user_service.dart';
import '../../diagnostic/pages/diagnostic_page.dart';
import '../widgets/complete_profile_dialog.dart';

/// Full-screen WebView that drives the Google OAuth flow on Android (and any
/// non-web platform).  It mirrors the logic in [OAuthCallbackPage] but works
/// entirely inside the app instead of relying on `dart:html`.
///
/// Flow:
///   1. Load  `<backend>/oauth2/authorization/google`  in the WebView.
///   2. The WebView follows every redirect (Google sign-in pages, backend
///      callback, etc.) automatically.
///   3. When the backend has finished processing it redirects to the frontend
///      URL with a one-time `code=` query / hash parameter.  We intercept that
///      navigation, extract the code, and prevent the WebView from loading the
///      (web-only) frontend page.
///   4. Exchange the code for a JWT via  `GET /user/oauth/token?code=<code>`.
///   5. Save the token and navigate to [DiagnosticPage] (new user) or
///      [HomeScreen] (returning user), exactly like [OAuthCallbackPage] does.
class GoogleAuthWebviewPage extends StatefulWidget {
  const GoogleAuthWebviewPage({super.key});

  @override
  State<GoogleAuthWebviewPage> createState() => _GoogleAuthWebviewPageState();
}

class _GoogleAuthWebviewPageState extends State<GoogleAuthWebviewPage> {
  late final WebViewController _controller;
  bool _pageLoading = true;
  bool _hasHandled = false; // guard against double-handling

  // ── Domains we must NOT intercept ─────────────────────────────────────────
  // These are part of the normal OAuth redirect chain and should be followed.
  static const _passthroughDomains = [
    'accounts.google.com',
    'focusprobackend.onrender.com',
    'oauth2.googleapis.com',
    'googleapis.com',
  ];

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _pageLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _pageLoading = false);
          },
          onNavigationRequest: (NavigationRequest req) {
            return _onNavRequest(req.url);
          },
          onWebResourceError: (WebResourceError error) {
            // Ignore errors from pages we intentionally block (prevented
            // navigations still fire resource errors on some Android versions).
            debugPrint('[GoogleAuthWebview] resource error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse('${AuthService.baseUrl}/oauth2/authorization/google'));
  }

  // ── Navigation interceptor ────────────────────────────────────────────────

  NavigationDecision _onNavRequest(String url) {
    if (_hasHandled) return NavigationDecision.prevent;

    // Only intercept URLs that carry a `code=` parameter AND are not part of
    // the standard OAuth redirect chain (Google sign-in / backend callback).
    final isPassthrough = _passthroughDomains.any((d) => url.contains(d));
    if (!isPassthrough && url.contains('code=')) {
      _hasHandled = true;
      // Run async work off the navigator callback.
      Future.microtask(() => _handleCallbackUrl(url));
      return NavigationDecision.prevent; // don't actually load the web page
    }

    return NavigationDecision.navigate;
  }

  // ── Token exchange & navigation ───────────────────────────────────────────

  Future<void> _handleCallbackUrl(String url) async {
    try {
      final code = _extractCode(url);
      if (code == null || code.isEmpty) {
        _failAndPop('Sign-in failed: no code in callback URL.');
        return;
      }

      // Exchange one-time code for JWT.
      final tokenUrl = Uri.parse('${AuthService.baseUrl}/user/oauth/token?code=$code');
      final resp = await http.get(tokenUrl);

      if (resp.statusCode != 200 || resp.body.trim().isEmpty) {
        _failAndPop('Sign-in failed (${resp.statusCode}). Please try again.');
        return;
      }

      final token = resp.body.trim();
      await AuthService.saveToken(token);

      // Fetch the user profile to decide where to route.
      await UserService.fetchAndSaveProfile(token);
      final profile = await UserService.getStoredProfile();

      final rawFocusScore = profile?['focusScore'];
      double? focusScore;
      if (rawFocusScore is double) {
        focusScore = rawFocusScore;
      } else if (rawFocusScore is int) {
        focusScore = rawFocusScore.toDouble();
      } else if (rawFocusScore is String && rawFocusScore.isNotEmpty) {
        focusScore = double.tryParse(rawFocusScore);
      }

      final isNewUser = focusScore == null || focusScore == 0.0;
      final hasConsented = profile?['consentUsage'] == true;

      if (!mounted) return;

      await context.read<UserProvider>().reloadAfterLogin();
      await context.read<DailyScoreProvider>().init();
      await context.read<HabitProvider>().load();

      if (!mounted) return;

      // Prompt for date-of-birth if Google user hasn't filled it in yet.
      if (profile?['dob'] == null) {
        await showCompleteProfileDialog(context, token);
        if (!mounted) return;
      }

      if (isNewUser) {
        // Show data-usage consent for brand-new users who haven't accepted yet.
        if (!hasConsented) {
          final consented = await _showConsentDialog();
          if (!mounted) return;
          if (consented == true) {
            await AuthService.activateConsent(token);
          }
        }
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => DiagnosticPage(token: token)));
      } else {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } catch (e, st) {
      debugPrint('[GoogleAuthWebview] ERROR: $e\n$st');
      _failAndPop('Something went wrong during sign-in. Please try again.');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Extracts the `code` value from a URL's query string or fragment.
  String? _extractCode(String url) {
    // Try standard query parameter first.
    final uri = Uri.tryParse(url);
    if (uri != null) {
      final fromQuery = uri.queryParameters['code'];
      if (fromQuery != null && fromQuery.isNotEmpty) return fromQuery;
    }

    // Fall back to raw split (handles hash fragments like #/oauth-callback?code=…).
    if (url.contains('code=')) {
      final raw = url.split('code=')[1].split('&')[0].split('#')[0];
      if (raw.isNotEmpty) return Uri.decodeComponent(raw);
    }
    return null;
  }

  void _failAndPop(String message) {
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
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
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [AppColors.primaryA, AppColors.primaryB]),
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
                'LockedIn collects focus-related data (session activity, '
                'diagnostic results, and usage patterns) to personalise your '
                'experience and improve the app.\n\nYour data is never sold '
                'and is handled in accordance with our privacy policy.',
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        title: const Text(
          'Sign in with Google',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.onSurface),
        ),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_pageLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
