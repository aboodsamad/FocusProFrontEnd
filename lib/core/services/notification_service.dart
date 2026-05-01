import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'auth_service.dart';
import 'browser_notification.dart';

const _kChannelId   = 'lockedin_main';
const _kChannelName = 'LockedIn Reminders';
const _kChannelDesc = 'Focus session and habit reminders';
const _kBackendBase = 'https://LockedInbackend.onrender.com';
const _kBgTaskName  = 'notificationPoll';
const _kBgTaskId    = 'lockedin-notification-poll';

// ── FCM background message handler ────────────────────────────────────────────
// Must be a top-level function. Called when the app is terminated/background
// and a data-only FCM message arrives. Notification-payload messages are shown
// automatically by the OS — nothing extra needed here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // The OS displays the notification automatically via the FCM notification payload.
}

// ── WorkManager background isolate entry-point ────────────────────────────────
// Must be a top-level function annotated with vm:entry-point.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // Each WorkManager run is a fresh isolate — init everything from scratch.
      final localNotifs = FlutterLocalNotificationsPlugin();
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      await localNotifs.initialize(
          const InitializationSettings(android: androidSettings));

      const channel = AndroidNotificationChannel(
        _kChannelId, _kChannelName,
        description: _kChannelDesc,
        importance: Importance.high,
      );
      await localNotifs
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) return true;

      final resp = await http.get(
        Uri.parse('$_kBackendBase/notifications/pending'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode != 200) return true;

      final list = jsonDecode(resp.body) as List<dynamic>;
      for (final n in list) {
        final id    = (n['id'] as num?)?.toInt();
        final title = (n['title']   as String?) ?? 'LockedIn';
        final body  = (n['message'] as String?) ?? '';

        await localNotifs.show(
          (id ?? 0) & 0x7FFFFFFF,
          title, body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _kChannelId, _kChannelName,
              channelDescription: _kChannelDesc,
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );

        if (id != null) {
          await http.post(
            Uri.parse('$_kBackendBase/notifications/$id/acknowledge'),
            headers: {'Authorization': 'Bearer $token'},
          ).timeout(const Duration(seconds: 5));
        }
      }
    } catch (e) {
      debugPrint('BG notification error: $e');
    }
    return true;
  });
}

// ── Foreground notification service ──────────────────────────────────────────
class NotificationService {
  static Timer? _pollTimer;
  static bool _initialized = false;
  static bool _pushSubscribed = false;

  static final FlutterLocalNotificationsPlugin _localNotifs =
      FlutterLocalNotificationsPlugin();
  static bool _localNotifsReady = false;

  /// Call once after login / on app start when already logged in.
  static Future<void> init() async {
    if (_initialized) return;

    if (!kIsWeb) {
      await _initLocalNotifications();
      // Register WorkManager periodic task for background delivery.
      await _registerBackgroundTask();
      // Register FCM token and listen for foreground messages.
      await _registerFcmToken();
      _setupFcmListeners();
    } else {
      await BrowserNotification.requestPermission();
      if (BrowserNotification.permissionStatus != 'granted') {
        debugPrint('Notification permission not granted — skipping push setup.');
        return;
      }
      await _setupWebPush();
    }

    // Mark initialized only after setup succeeded, so a retry is possible.
    _initialized = true;
    _startPolling();
  }

  // ── Android foreground init ───────────────────────────────────────────────

  static Future<void> _initLocalNotifications() async {
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _localNotifs.initialize(
          const InitializationSettings(android: androidSettings));

      const channel = AndroidNotificationChannel(
        _kChannelId, _kChannelName,
        description: _kChannelDesc,
        importance: Importance.high,
      );
      final androidPlugin = _localNotifs
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(channel);
      await androidPlugin?.requestNotificationsPermission();

      _localNotifsReady = true;
      debugPrint('Android local notifications ready.');
    } catch (e) {
      debugPrint('Local notifications init error: $e');
    }
  }

  // ── WorkManager background task registration ──────────────────────────────

  static Future<void> _registerBackgroundTask() async {
    try {
      await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
      await Workmanager().registerPeriodicTask(
        _kBgTaskId,
        _kBgTaskName,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: const Duration(minutes: 5),
      );
      debugPrint('WorkManager background task registered.');
    } catch (e) {
      debugPrint('WorkManager registration error: $e');
    }
  }

  // ── Web Push ──────────────────────────────────────────────────────────────

  static Future<void> _setupWebPush() async {
    final token = await AuthService.getToken();
    if (token == null) return;
    try {
      final keyResp = await http
          .get(
            Uri.parse('${AuthService.baseUrl}/notifications/vapid-public-key'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
      if (keyResp.statusCode != 200) return;
      final vapidKey =
          (jsonDecode(keyResp.body) as Map<String, dynamic>)['key'] as String? ?? '';
      if (vapidKey.isEmpty) {
        debugPrint('VAPID key not configured — using polling only.');
        return;
      }
      final subscription = await BrowserNotification.subscribeToWebPush(vapidKey);
      if (subscription == null) {
        debugPrint('Web push subscription failed — using polling only.');
        return;
      }
      final subResp = await http
          .post(
            Uri.parse('${AuthService.baseUrl}/notifications/web-push-subscribe'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(subscription),
          )
          .timeout(const Duration(seconds: 10));
      if (subResp.statusCode == 200) {
        _pushSubscribed = true;
        debugPrint('Web push subscription registered.');
      }
    } catch (e) {
      debugPrint('Web push setup error: $e');
    }
  }

  // ── Foreground polling ────────────────────────────────────────────────────

  static void _startPolling() {
    _pollTimer?.cancel();
    _checkForNotifications();
    int tick = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      tick++;
      if (kIsWeb && !_pushSubscribed && tick % 4 == 0) {
        await _setupWebPush();
      }
      _checkForNotifications();
    });
  }

  static Future<void> _checkForNotifications() async {
    if (kIsWeb) {
      if (!BrowserNotification.isSupported) return;
      if (BrowserNotification.permissionStatus != 'granted') return;
    }

    final token = await AuthService.getToken();
    if (token == null) return;

    try {
      final resp = await http
          .get(
            Uri.parse('${AuthService.baseUrl}/notifications/pending'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return;

      final notifications = jsonDecode(resp.body) as List<dynamic>;
      for (final n in notifications) {
        final id    = (n['id']      as num?)?.toInt();
        final title = (n['title']   as String?) ?? 'LockedIn';
        final msg   = (n['message'] as String?) ?? '';

        await _showNotification(id ?? 0, title, msg);
        if (id != null) _acknowledge(id, token);
      }
    } catch (e) {
      debugPrint('Notification poll error: $e');
    }
  }

  static Future<void> _showNotification(int id, String title, String body) async {
    if (kIsWeb) {
      BrowserNotification.show(title, body);
    } else if (_localNotifsReady) {
      await _localNotifs.show(
        id & 0x7FFFFFFF,
        title, body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _kChannelId, _kChannelName,
            channelDescription: _kChannelDesc,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    }
  }

  static Future<void> _acknowledge(int id, String token) async {
    try {
      await http
          .post(
            Uri.parse('${AuthService.baseUrl}/notifications/$id/acknowledge'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  // ── FCM token registration ────────────────────────────────────────────────

  static Future<void> _registerFcmToken() async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true, badge: true, sound: true,
      );
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _saveFcmToken(token);
      // Re-register whenever Firebase rotates the token.
      FirebaseMessaging.instance.onTokenRefresh.listen(_saveFcmToken);
    } catch (e) {
      debugPrint('FCM token registration error: $e');
    }
  }

  static Future<void> _saveFcmToken(String token) async {
    final authToken = await AuthService.getToken();
    if (authToken == null) return;
    try {
      await http.post(
        Uri.parse('$_kBackendBase/notifications/fcm-token'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'token': token}),
      ).timeout(const Duration(seconds: 10));
      debugPrint('FCM token registered with backend.');
    } catch (e) {
      debugPrint('FCM token save error: $e');
    }
  }

  static void _setupFcmListeners() {
    // When the app is in the foreground, FCM does NOT auto-display notifications.
    // We intercept them here and show via flutter_local_notifications.
    FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
      final title = msg.notification?.title ?? (msg.data['title'] as String?) ?? 'LockedIn';
      final body  = msg.notification?.body  ?? (msg.data['body']  as String?) ?? '';
      _showNotification(msg.hashCode & 0x7FFFFFFF, title, body);
    });
  }

  /// Call on logout to stop foreground polling and reset state.
  static void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _initialized = false;
    _pushSubscribed = false;
    _localNotifsReady = false;
    // Note: WorkManager periodic task persists across logout by design —
    // it checks for a valid token before doing anything.
  }
}
