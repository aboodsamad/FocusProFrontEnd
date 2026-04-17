// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'dart:convert';
import 'dart:typed_data';

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

  /// Subscribe to VAPID Web Push using the service worker registered in index.html.
  /// Returns the subscription JSON (endpoint + keys) to send to the backend.
  /// Returns null if push is not supported or user denied permission.
  static Future<Map<String, dynamic>?> subscribeToWebPush(String vapidPublicKey) async {
    if (vapidPublicKey.isEmpty) return null;
    if (!isSupported) return null;
    if (html.Notification.permission != 'granted') return null;

    try {
      // Get the service worker registration we set on window._focusproNotifSW
      final swReg = js.context['_focusproNotifSW'];
      if (swReg == null) return null;

      final pushManager = swReg['pushManager'];
      if (pushManager == null) return null;

      // Check for existing subscription first
      final existing = await _promiseToFuture(pushManager.callMethod('getSubscription', []));
      final sub = existing ?? await _promiseToFuture(
        pushManager.callMethod('subscribe', [
          js.JsObject.jsify({
            'userVisibleOnly': true,
            'applicationServerKey': _urlBase64ToUint8Array(vapidPublicKey),
          })
        ]),
      );

      if (sub == null) return null;

      // Convert JsObject subscription to Dart map
      final subJson = _promiseResultToMap(sub);
      return subJson;
    } catch (e) {
      return null;
    }
  }

  // Convert JS Promise to Dart Future
  static Future<dynamic> _promiseToFuture(js.JsObject? promise) {
    if (promise == null) return Future.value(null);
    return js.promiseToFuture(promise);
  }

  // Convert the PushSubscription JsObject to a Dart map suitable for the backend
  static Map<String, dynamic>? _promiseResultToMap(dynamic sub) {
    try {
      final json = js.context['JSON'].callMethod('stringify', [sub]);
      if (json == null) return null;
      return jsonDecode(json.toString()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // Convert VAPID public key (base64url) to Uint8Array for PushManager.subscribe
  static Uint8List _urlBase64ToUint8Array(String base64String) {
    String padded = base64String
        .replaceAll('-', '+')
        .replaceAll('_', '/');
    while (padded.length % 4 != 0) padded += '=';
    return base64Decode(padded);
  }
}
