class RoomMember {
  final String username;
  final String displayName;
  final String? goal;
  final String joinedAt;

  RoomMember({
    required this.username,
    required this.displayName,
    this.goal,
    required this.joinedAt,
  });

  factory RoomMember.fromJson(Map<String, dynamic> json) => RoomMember(
        username: json['username'] ?? '',
        displayName: json['displayName'] ?? json['username'] ?? '',
        goal: json['goal'],
        joinedAt: json['joinedAt'] ?? '',
      );
}

class FocusRoom {
  final int id;
  final String name;
  final String emoji;
  final String createdBy;
  final int memberCount;
  final List<RoomMember> members;

  FocusRoom({
    required this.id,
    required this.name,
    required this.emoji,
    required this.createdBy,
    required this.memberCount,
    required this.members,
  });

  factory FocusRoom.fromJson(Map<String, dynamic> json) => FocusRoom(
        id: json['id'],
        name: json['name'] ?? '',
        emoji: json['emoji'] ?? '🎯',
        createdBy: json['createdBy'] ?? '',
        memberCount: json['memberCount'] ?? 0,
        members: (json['members'] as List<dynamic>? ?? [])
            .map((m) => RoomMember.fromJson(m as Map<String, dynamic>))
            .toList(),
      );
}

class RoomEvent {
  final String eventType; // "JOIN" or "LEAVE"
  final String triggeredBy;
  final List<RoomMember> members;

  RoomEvent({
    required this.eventType,
    required this.triggeredBy,
    required this.members,
  });

  factory RoomEvent.fromJson(Map<String, dynamic> json) => RoomEvent(
        eventType: json['eventType'] ?? '',
        triggeredBy: json['triggeredBy'] ?? '',
        members: (json['members'] as List<dynamic>? ?? [])
            .map((m) => RoomMember.fromJson(m as Map<String, dynamic>))
            .toList(),
      );
}
