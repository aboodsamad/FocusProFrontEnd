import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:capstone_front_end/core/utils/url_helper.dart';
import 'features/home/providers/user_provider.dart';
import 'features/auth/pages/login_page.dart';
import 'features/auth/pages/oauth_callback_page.dart';
import 'features/home/pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final userProvider = UserProvider();
  await userProvider.init();

  runApp(
    ChangeNotifierProvider.value(
      value: userProvider,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.read<UserProvider>();

    return MaterialApp(
      title: 'FocusPro',
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        final hash = getLocationHash();
        if (hash.contains('/oauth-callback')) {
          return MaterialPageRoute(
            builder: (_) => OAuthCallbackPage(),
          );
        }
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (_) => userProvider.isLoggedIn
                  ? const HomeScreen()
                  : LoginPage(),
            );
          case '/home':
            return MaterialPageRoute(builder: (_) => const HomeScreen());
          default:
            return MaterialPageRoute(
              builder: (_) => userProvider.isLoggedIn
                  ? const HomeScreen()
                  : LoginPage(),
            );
        }
      },
    );
  }
}