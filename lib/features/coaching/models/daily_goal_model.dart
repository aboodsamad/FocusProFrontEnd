class DailyGoalModel {
  final int id;
  final String goalText;
  final String status; // PENDING, IN_PROGRESS, DONE, SKIPPED
  final String goalDate;

  const DailyGoalModel({
    required this.id,
    required this.goalText,
    required this.status,
    required this.goalDate,
  });

  factory DailyGoalModel.fromJson(Map<String, dynamic> json) {
    return DailyGoalModel(
      id: _parseInt(json['id'] ?? json['goalId'] ?? 0),
      goalText: json['goalText'] as String? ?? json['goal_text'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      goalDate: json['goalDate'] as String? ?? json['goal_date'] as String? ?? '',
    );
  }

  static int _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  DailyGoalModel copyWith({String? status}) {
    return DailyGoalModel(
      id: id,
      goalText: goalText,
      status: status ?? this.status,
      goalDate: goalDate,
    );
  }
}
