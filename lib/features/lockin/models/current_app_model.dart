/// Represents the app the user is currently looking at,
/// as reported by FocusProAccessibilityService.
class CurrentAppModel {
  /// Android package name, e.g. "com.instagram.android"
  final String packageName;

  /// Human-readable app label, e.g. "Instagram"
  final String appName;

  /// The activity/screen inside the app, e.g. "com.instagram.android.activity.MainTabActivity"
  final String activityName;

  /// Whether the accessibility service is actively running.
  final bool serviceRunning;

  const CurrentAppModel({
    required this.packageName,
    required this.appName,
    required this.activityName,
    required this.serviceRunning,
  });

  factory CurrentAppModel.fromJson(Map<String, dynamic> j) {
    return CurrentAppModel(
      packageName: j['packageName'] as String? ?? '',
      appName: j['appName'] as String? ?? j['packageName'] as String? ?? '',
      activityName: j['activityName'] as String? ?? '',
      serviceRunning: j['serviceRunning'] as bool? ?? false,
    );
  }

  @override
  String toString() =>
      'CurrentAppModel(appName: $appName, package: $packageName, activity: $activityName)';
}
