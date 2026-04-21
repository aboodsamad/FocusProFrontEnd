class DailyChallengeModel {
  final int id;
  final String challengeType; // GAME / BOOK / CUSTOM
  final String? targetGameType;
  final int? targetBookId;
  final String challengeTitle;
  final String challengeDescription;
  final String weaknessArea;
  final String challengeDate;
  final String? completedAt;
  final String? expiresAt;
  final bool isExpired;
  final bool isCompleted;

  const DailyChallengeModel({
    required this.id,
    required this.challengeType,
    this.targetGameType,
    this.targetBookId,
    required this.challengeTitle,
    required this.challengeDescription,
    required this.weaknessArea,
    required this.challengeDate,
    this.completedAt,
    this.expiresAt,
    required this.isExpired,
    required this.isCompleted,
  });

  factory DailyChallengeModel.fromJson(Map<String, dynamic> json) {
    return DailyChallengeModel(
      id: (json['id'] as num).toInt(),
      challengeType: json['challengeType'] as String? ?? 'CUSTOM',
      targetGameType: json['targetGameType'] as String?,
      targetBookId: json['targetBookId'] != null
          ? (json['targetBookId'] as num).toInt()
          : null,
      challengeTitle: json['challengeTitle'] as String? ?? 'Today\'s Challenge',
      challengeDescription: json['challengeDescription'] as String? ?? '',
      weaknessArea: json['weaknessArea'] as String? ?? 'memory',
      challengeDate: json['challengeDate']?.toString() ?? '',
      completedAt: json['completedAt']?.toString(),
      expiresAt: json['expiresAt']?.toString(),
      isExpired: json['expired'] as bool? ?? false,
      isCompleted: json['completed'] as bool? ?? (json['completedAt'] != null),
    );
  }
}
