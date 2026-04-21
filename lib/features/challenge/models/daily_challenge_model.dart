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

  // Handles int, double, or string representations of the book id
  static int? _parseId(dynamic v) {
    if (v == null) return null;
    if (v is int) return v > 0 ? v : null;
    if (v is double) return v > 0 ? v.toInt() : null;
    if (v is String) {
      final parsed = int.tryParse(v.trim());
      return (parsed != null && parsed > 0) ? parsed : null;
    }
    return null;
  }

  factory DailyChallengeModel.fromJson(Map<String, dynamic> json) {
    return DailyChallengeModel(
      id: (json['id'] as num).toInt(),
      challengeType: json['challengeType'] as String? ?? 'CUSTOM',
      targetGameType: json['targetGameType'] as String?,
      targetBookId: _parseId(json['targetBookId']),
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
