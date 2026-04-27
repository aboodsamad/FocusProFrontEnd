import 'dart:typed_data';

String getLocationHash() => '';
String getLocationPathname() => '';
String getLocationSearch() => '';
void openUrl(String url) {}
void replaceState(String url) {}

String createAudioBlobUrl(Uint8List bytes) => '';
void revokeAudioBlobUrl(String url) {}

class WebAudioProxy {
  void Function(Duration)? onDuration;
  void Function(Duration, double)? onPosition;
  void Function(bool)? onPlaying;
  void Function()? onEnded;
  bool get isPlaying => false;
  void play(String blobUrl, double speed) {}
  void pause() {}
  void resume() {}
  void seek(Duration pos) {}
  void setSpeed(double speed) {}
  void stop() {}
  void dispose() {}
}

WebAudioProxy createWebAudioProxy() => WebAudioProxy();