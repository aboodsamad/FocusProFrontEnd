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
      id: (json['id'] as num).toInt(),
      goalText: json['goalText'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      goalDate: json['goalDate'] as String? ?? '',
    );
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
