// No-op for mobile and desktop platforms.
class BrowserNotification {
  static Future<void> requestPermission() async {}
  static bool get isSupported => false;
  static void show(String title, String body) {}
}
