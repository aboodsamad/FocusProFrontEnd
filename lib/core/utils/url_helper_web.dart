// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

String getLocationHash() => html.window.location.hash;
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

/// Web-only audio controller backed by the browser's native HTMLAudioElement.
/// Used instead of just_audio on web to avoid MissingPluginException from the
/// native method channel (com.ryanheise.just_audio.methods) which has no
/// implementation in web builds.
class WebAudioProxy {
  html.AudioElement? _element;
  final List<StreamSubscription<html.Event>> _subs = [];

  void Function(Duration)? onDuration;
  void Function(Duration, double)? onPosition;
  void Function(bool)? onPlaying;
  void Function()? onEnded;

  bool get isPlaying => _element != null && !_element!.paused && !_element!.ended;

  void play(String blobUrl, double speed) {
    _disposeElement();
    final el = html.AudioElement()..src = blobUrl;
    el.playbackRate = speed;
    _element = el;

    _subs.add(el.onDurationChange.listen((_) {
      final d = _element?.duration ?? double.nan;
      if (!d.isNaN && d.isFinite && d > 0) {
        onDuration?.call(Duration(milliseconds: (d * 1000).round()));
      }
    }));

    _subs.add(el.onTimeUpdate.listen((_) {
      final cur = _element?.currentTime ?? 0.0;
      final dur = _element?.duration ?? 0.0;
      final pos = Duration(milliseconds: (cur * 1000).round());
      final progress = dur > 0 ? (cur / dur).clamp(0.0, 1.0) : 0.0;
      onPosition?.call(pos, progress);
    }));

    _subs.add(el.onPlay.listen((_) => onPlaying?.call(true)));

    _subs.add(el.onPause.listen((_) {
      // onPause fires before onEnded; skip the false-playing signal on natural end.
      if (_element?.ended ?? false) return;
      onPlaying?.call(false);
    }));

    _subs.add(el.onEnded.listen((_) {
      onPlaying?.call(false);
      onEnded?.call();
    }));

    el.play();
  }

  void pause() => _element?.pause();
  void resume() => _element?.play();

  void seek(Duration pos) {
    if (_element != null) _element!.currentTime = pos.inMilliseconds / 1000.0;
  }

  void setSpeed(double speed) {
    if (_element != null) _element!.playbackRate = speed;
  }

  void stop() => _disposeElement();

  void _disposeElement() {
    _element?.pause();
    if (_element != null) _element!.src = '';
    _element = null;
    for (final s in _subs) { s.cancel(); }
    _subs.clear();
  }

  void dispose() {
    _disposeElement();
    onDuration = null;
    onPosition = null;
    onPlaying = null;
    onEnded = null;
  }
}

WebAudioProxy createWebAudioProxy() => WebAudioProxy();