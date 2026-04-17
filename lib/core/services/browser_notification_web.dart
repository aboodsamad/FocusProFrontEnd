// Web-only: uses the browser's native Notification API.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class BrowserNotification {
  static Future<void> requestPermission() async {
    if (!isSupported) return;
    await html.Notification.requestPermission();
  }

  static bool get isSupported => html.Notification.supported;

  static void show(String title, String body) {
    if (!isSupported) return;
    if (html.Notification.permission == 'granted') {
      html.Notification(title, body: body, icon: '/icons/Icon-192.png');
    }
  }
}
