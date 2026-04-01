class ActivityLog {
  final int id;
  final String activityType;
  final String? activityDescription;
  final String? activityData;
  final DateTime activityDate;

  const ActivityLog({
    required this.id,
    required this.activityType,
    this.activityDescription,
    this.activityData,
    required this.activityDate,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: (json['id'] as num).toInt(),
      activityType: json['activityType'] as String,
      activityDescription: json['activityDescription'] as String?,
      activityData: json['activityData'] as String?,
      activityDate: DateTime.parse(json['activityDate'] as String),
    );
  }
}
