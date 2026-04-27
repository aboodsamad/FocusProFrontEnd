// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

String getLocationHash() => html.window.location.hash ?? '';
String getLocationPathname() => html.window.location.pathname ?? '';
String getLocationSearch() => html.window.location.search ?? '';
void openUrl(String url) => html.window.open(url, '_self');
void replaceState(String url) =>
    html.window.history.replaceState(null, '', url);

/// Creates a temporary blob:// URL from raw MP3 bytes.
/// The browser serves the audio from memory — no base64 size limits, and
/// blob URLs are treated as same-origin resources so autoplay works reliably.
String createAudioBlobUrl(Uint8List bytes) {
  final blob = html.Blob([bytes], 'audio/mpeg');
  return html.Url.createObjectUrl(blob);
}

/// Releases the memory held by a previously created blob URL.
void revokeAudioBlobUrl(String url) => html.Url.revokeObjectUrl(url);