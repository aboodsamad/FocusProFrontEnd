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
    DateTime date;
    try {
      date = DateTime.parse((json['activityDate'] ?? '').toString());
    } catch (_) {
      date = DateTime.now();
    }
    return ActivityLog(
      id: (json['id'] as num?)?.toInt() ?? 0,
      activityType: (json['activityType'] as String?) ?? 'unknown',
      activityDescription: json['activityDescription'] as String?,
      activityData: json['activityData'] as String?,
      activityDate: date,
    );
  }
}
