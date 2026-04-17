// No-op for mobile and desktop platforms.
class BrowserNotification {
  static Future<void> requestPermission() async {}
  static bool get isSupported => false;
  static String get permissionStatus => 'denied';
  static void show(String title, String body) {}
  static Future<Map<String, dynamic>?> subscribeToWebPush(String vapidPublicKey) async => null;
}
