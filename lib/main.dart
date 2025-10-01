import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pages/login_page.dart';
import 'pages/homePage.dart';
import './providers/app_provider.dart';
import './services/oath_redirect.dart';
import 'dart:html' as html;


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ChangeNotifierProvider(create: (_) => Edit(), child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My App',
      initialRoute: '/home',
      onGenerateRoute: (settings) {
        // Check if URL contains oauth-callback
        final hash = html.window.location.hash;
        if (hash.contains('/oauth-callback')) {
          return MaterialPageRoute(builder: (_) => OAuthCallbackPage());
        }
        
        // Regular routes
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

