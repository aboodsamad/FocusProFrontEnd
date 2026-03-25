// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

String getLocationHash() => html.window.location.hash ?? '';
String getLocationPathname() => html.window.location.pathname ?? '';
String getLocationSearch() => html.window.location.search ?? '';
void openUrl(String url) => html.window.open(url, '_self');
void replaceState(String url) =>
    html.window.history.replaceState(null, '', url);