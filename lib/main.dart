import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:capstone_front_end/core/utils/url_helper.dart';
import 'core/services/notification_service.dart';
import 'features/home/providers/user_provider.dart';
import 'features/habits/providers/habit_provider.dart';
import 'features/auth/pages/login_page.dart';
import 'features/auth/pages/oauth_callback_page.dart';
import 'features/home/pages/home_page.dart';
import './features/diagnostic/pages/diagnostic_page.dart';
import 'features/coaching/pages/coaching_page.dart';
import 'features/games/hub/pages/games_hub_page.dart';
import 'features/books/pages/books_page.dart';
import 'features/habits/pages/manage_habits_page.dart';
import 'features/focus_session/pages/focus_rooms_page.dart';
import 'features/profile/pages/profile_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final userProvider = UserProvider();
  await userProvider.init();

  final habitProvider = HabitProvider();
  if (userProvider.isLoggedIn) {
    await habitProvider.load();
    // Start notification polling if already logged in
    NotificationService.init();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: userProvider),
        ChangeNotifierProvider.value(value: habitProvider),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.read<UserProvider>();

    // On web, read the hash so a reload stays on the same page (#/profile → /profile).
    final hash = getLocationHash();
    final String initialRoute = (hash.startsWith('#/') && !hash.contains('oauth-callback') && !hash.contains('token='))
        ? hash.substring(1)
        : '/';

    return MaterialApp(
      title: 'FocusPro',
      debugShowCheckedModeBanner: false,
      initialRoute: initialRoute,
      onGenerateRoute: (settings) {
        final hash   = getLocationHash();
        final search = getLocationSearch();
        // Detect OAuth redirect regardless of where the token/callback lands:
        // – hash contains "/oauth-callback"  (#/oauth-callback?token=…)
        // – hash contains "token=" directly  (#token=…)
        // – query string contains "token="   (?token=…)
        if (hash.contains('/oauth-callback') ||
            hash.contains('token=') ||
            search.contains('token=')) {
          return MaterialPageRoute(
            builder: (_) => OAuthCallbackPage(),
          );
        }
        // Helper: redirect to login if not authenticated
        MaterialPageRoute authGate(Widget Function() page) {
          return MaterialPageRoute(
            builder: (_) => userProvider.isLoggedIn ? page() : LoginPage(),
          );
        }

        switch (settings.name) {
          case '/':
          case '/home':
            return authGate(() => const HomeScreen());
          case '/coaching':
            return authGate(() => const CoachingPage());
          case '/games':
            return authGate(() => const GamesHubPage());
          case '/books':
            return authGate(() => const BooksPage());
          case '/habits':
            return authGate(() => const ManageHabitsPage());
          case '/rooms':
            return authGate(() => const FocusRoomsPage());
          case '/profile':
            return authGate(() => const ProfilePage());
          case '/diagnostic':
            return authGate(() => const DiagnosticPage());
          default:
            return authGate(() => const HomeScreen());
        }
      },
    );
  }
}