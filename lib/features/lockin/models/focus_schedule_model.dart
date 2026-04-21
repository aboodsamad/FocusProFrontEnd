class FocusScheduleModel {
  final int id;
  final int userId;
  final String scheduleType;
  final String scheduledTime;
  final int durationMinutes;
  final int prepTimerMinutes;
  final bool isRecurring;
  final String? daysOfWeek;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? lastTriggeredAt;

  const FocusScheduleModel({
    required this.id,
    required this.userId,
    required this.scheduleType,
    required this.scheduledTime,
    required this.durationMinutes,
    required this.prepTimerMinutes,
    required this.isRecurring,
    this.daysOfWeek,
    required this.isActive,
    this.createdAt,
    this.lastTriggeredAt,
  });

  factory FocusScheduleModel.fromJson(Map<String, dynamic> j) {
    DateTime? parseTs(dynamic v) {
      if (v == null) return null;
      try { return DateTime.parse(v as String); } catch (_) { return null; }
    }
    return FocusScheduleModel(
      id: (j['id'] as num).toInt(),
      userId: (j['userId'] as num).toInt(),
      scheduleType: j['scheduleType'] as String,
      scheduledTime: j['scheduledTime'] as String,
      durationMinutes: (j['durationMinutes'] as num).toInt(),
      prepTimerMinutes: (j['prepTimerMinutes'] as num? ?? 5).toInt(),
      isRecurring: j['recurring'] as bool? ?? j['isRecurring'] as bool? ?? false,
      daysOfWeek: j['daysOfWeek'] as String?,
      isActive: j['active'] as bool? ?? j['isActive'] as bool? ?? true,
      createdAt: parseTs(j['createdAt']),
      lastTriggeredAt: parseTs(j['lastTriggeredAt']),
    );
  }
}
