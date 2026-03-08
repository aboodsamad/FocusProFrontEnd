import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:html' as html;
import 'features/auth/pages/login_page.dart';
import 'features/auth/pages/oauth_callback_page.dart';
import 'features/home/pages/home_page.dart';

// AppProvider removed — it was empty. Add it back here when you
// need real cross-page state (e.g. logged-in user, theme, etc.)

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FocusPro',
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        // Handle Google OAuth callback
        final hash = html.window.location.hash;
        if (hash.contains('/oauth-callback')) {
          return MaterialPageRoute(builder: (_) => OAuthCallbackPage());
        }

        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => LoginPage());
          case '/home':
            return MaterialPageRoute(builder: (_) => HomeScreen());
          default:
            return MaterialPageRoute(builder: (_) => LoginPage());
        }
      },
    );
  }
}
