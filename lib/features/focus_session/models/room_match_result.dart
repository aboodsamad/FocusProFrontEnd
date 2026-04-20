class RoomMatchResult {
  final int? roomId;
  final String roomName;
  final String roomEmoji;
  final int memberCount;
  final double matchScore;
  final String matchReason;
  final List<String> memberGoals;
  final bool isNewRoomSuggestion;

  RoomMatchResult({
    required this.roomId,
    required this.roomName,
    required this.roomEmoji,
    required this.memberCount,
    required this.matchScore,
    required this.matchReason,
    required this.memberGoals,
    required this.isNewRoomSuggestion,
  });

  factory RoomMatchResult.fromJson(Map<String, dynamic> json) => RoomMatchResult(
        roomId: json['roomId'] as int?,
        roomName: json['roomName'] ?? '',
        roomEmoji: json['roomEmoji'] ?? '🎯',
        memberCount: json['memberCount'] ?? 0,
        matchScore: (json['matchScore'] as num?)?.toDouble() ?? 0.0,
        matchReason: json['matchReason'] ?? '',
        memberGoals: (json['memberGoals'] as List<dynamic>? ?? [])
            .map((g) => g as String)
            .toList(),
        isNewRoomSuggestion: json['isNewRoomSuggestion'] ?? false,
      );
}
