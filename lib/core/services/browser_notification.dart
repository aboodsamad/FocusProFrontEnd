// Conditional export: uses dart:html on web, no-op stub on mobile/desktop.
export 'browser_notification_stub.dart'
    if (dart.library.html) 'browser_notification_web.dart';
