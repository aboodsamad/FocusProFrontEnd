// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'dart:async';
import 'dart:convert';

class BrowserNotification {
  static Future<void> requestPermission() async {
    if (!isSupported) return;
    await html.Notification.requestPermission();
  }

  static bool get isSupported => html.Notification.supported;

  static String get permissionStatus => html.Notification.permission ?? 'default';

  static void show(String title, String body) {
    if (!isSupported) return;
    if (html.Notification.permission == 'granted') {
      html.Notification(title, body: body, icon: '/icons/Icon-192.png');
    }
  }

  /// Subscribe to VAPID Web Push.
  /// The actual subscription is done by JS in index.html (_focuspro_subscribePush)
  /// to avoid dart:js_util / allowInterop issues in Dart 3.8.
  /// Returns the subscription JSON (endpoint + keys) or null on failure.
  static Future<Map<String, dynamic>?> subscribeToWebPush(String vapidPublicKey) async {
    if (vapidPublicKey.isEmpty) return null;
    if (!isSupported) return null;
    if (html.Notification.permission != 'granted') return null;

    try {
      // Reset result and kick off JS subscription
      js.context['_focuspro_pushResult'] = null;
      js.context.callMethod('_focuspro_subscribePush', [vapidPublicKey]);

      // Poll for up to 15 seconds until JS finishes
      for (int i = 0; i < 150; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        final result = js.context['_focuspro_pushResult'];
        if (result == null) continue;

        // Convert JsObject → Dart map via JSON round-trip
        final jsonStr = js.context['JSON'].callMethod('stringify', [result]) as String?;
        if (jsonStr == null) return null;
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        if (map.containsKey('error')) return null;
        return map;
      }
      return null; // timed out
    } catch (e) {
      return null;
    }
  }
}
