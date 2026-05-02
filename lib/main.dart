import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:LockedIn/core/utils/url_helper.dart';
import 'core/services/notification_service.dart';
import 'features/home/providers/user_provider.dart';
import 'features/habits/providers/habit_provider.dart';
import 'core/providers/daily_score_provider.dart';
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
import 'features/lockin/pages/lock_in_page.dart';
import 'features/lockin/services/screen_event_syncer.dart';
import 'features/lockin/services/android_lockin_helper.dart' show AndroidLockInHelper;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  final userProvider = UserProvider();
  await userProvider.init();

  final habitProvider = HabitProvider();
  final dailyScoreProvider = DailyScoreProvider();
  if (userProvider.isLoggedIn) {
    await habitProvider.load();
    await dailyScoreProvider.init();
    // Start notification polling if already logged in
    NotificationService.init();
    // Start screen-event syncer  uses PACKAGE_USAGE_STATS, no extra permission needed
    final hasUsage = await AndroidLockInHelper.hasUsageStatsPermission();
    if (hasUsage) ScreenEventSyncer.instance.start();
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: userProvider),
        ChangeNotifierProvider.value(value: habitProvider),
        ChangeNotifierProvider.value(value: dailyScoreProvider),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const _triggerChannel = MethodChannel('LockedIn/lockin_trigger');
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _triggerChannel.setMethodCallHandler((call) async {
      if (call.method == 'onLockInTrigger') {
        final scheduleId = call.arguments as int?;
        _navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => LockInPage(triggerScheduleId: scheduleId)));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.read<UserProvider>();

    // On web, read the hash so a reload stays on the same page (#/profile → /profile).
    final hash = getLocationHash();
    final String initialRoute = (hash.startsWith('#/') && !hash.contains('oauth-callback') && !hash.contains('token='))
        ? hash.substring(1)
        : '/';

    return MaterialApp(
      title: 'LockedIn',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      initialRoute: initialRoute,
      onGenerateRoute: (settings) {
        final hash = getLocationHash();
        final search = getLocationSearch();
        // Detect OAuth redirect regardless of where the token/callback lands:
        // – hash contains "/oauth-callback"  (#/oauth-callback?token=…)
        // – hash contains "token=" directly  (#token=…)
        // – query string contains "token="   (?token=…)
        if (hash.contains('/oauth-callback') || hash.contains('token=') || search.contains('token=')) {
          return MaterialPageRoute(builder: (_) => OAuthCallbackPage());
        }
        // Helper: redirect to login if not authenticated
        MaterialPageRoute authGate(Widget Function() page) {
          return MaterialPageRoute(builder: (_) => userProvider.isLoggedIn ? page() : LoginPage());
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
            return authGate(() => const DiagnosticPage());
        }
      },
    );
  }
}
