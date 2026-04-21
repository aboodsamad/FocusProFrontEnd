class LockInSessionModel {
  final int id;
  final int? scheduleId;
  final DateTime sessionDate;
  final DateTime startedAt;
  final DateTime prepEndsAt;
  final DateTime scheduledEndsAt;
  final DateTime? endedAt;
  final bool endedEarly;
  final int? linkedCoachingSessionId;
  final bool isPrepPhase;
  final bool isActive;

  const LockInSessionModel({
    required this.id,
    this.scheduleId,
    required this.sessionDate,
    required this.startedAt,
    required this.prepEndsAt,
    required this.scheduledEndsAt,
    this.endedAt,
    required this.endedEarly,
    this.linkedCoachingSessionId,
    required this.isPrepPhase,
    required this.isActive,
  });

  factory LockInSessionModel.fromJson(Map<String, dynamic> j) {
    DateTime parseTs(dynamic v) {
      try { return DateTime.parse(v as String); } catch (_) { return DateTime.now(); }
    }
    DateTime? parseTsOpt(dynamic v) {
      if (v == null) return null;
      try { return DateTime.parse(v as String); } catch (_) { return null; }
    }
    return LockInSessionModel(
      id: (j['id'] as num).toInt(),
      scheduleId: j['scheduleId'] != null ? (j['scheduleId'] as num).toInt() : null,
      sessionDate: parseTs(j['sessionDate']),
      startedAt: parseTs(j['startedAt']),
      prepEndsAt: parseTs(j['prepEndsAt']),
      scheduledEndsAt: parseTs(j['scheduledEndsAt']),
      endedAt: parseTsOpt(j['endedAt']),
      endedEarly: j['endedEarly'] as bool? ?? false,
      linkedCoachingSessionId: j['linkedCoachingSessionId'] != null
          ? (j['linkedCoachingSessionId'] as num).toInt()
          : null,
      isPrepPhase: j['prepPhase'] as bool? ?? j['isPrepPhase'] as bool? ?? false,
      isActive: j['active'] as bool? ?? j['isActive'] as bool? ?? false,
    );
  }
}
