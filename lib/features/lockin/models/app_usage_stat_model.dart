class AppUsageStatModel {
  final String packageName;
  final String appName;
  final int totalMinutesToday;

  const AppUsageStatModel({
    required this.packageName,
    required this.appName,
    required this.totalMinutesToday,
  });

  factory AppUsageStatModel.fromJson(Map<String, dynamic> j) {
    return AppUsageStatModel(
      packageName: j['packageName'] as String? ?? '',
      appName: j['appName'] as String? ?? j['packageName'] as String? ?? '',
      totalMinutesToday: (j['totalMinutesToday'] as num? ?? 0).toInt(),
    );
  }
}
