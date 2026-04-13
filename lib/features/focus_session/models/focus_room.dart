import 'package:flutter/material.dart';

// ── Category metadata ─────────────────────────────────────────────────────────

const kCategories = [
  {'name': 'Study',       'emoji': '📚', 'color': Color(0xFF6C63FF)},
  {'name': 'Work',        'emoji': '💼', 'color': Color(0xFF10B981)},
  {'name': 'Creative',    'emoji': '🎨', 'color': Color(0xFFF59E0B)},
  {'name': 'Fitness',     'emoji': '💪', 'color': Color(0xFFEF4444)},
  {'name': 'Mindfulness', 'emoji': '🧘', 'color': Color(0xFF06B6D4)},
  {'name': 'Gaming',      'emoji': '🎮', 'color': Color(0xFF8B5CF6)},
  {'name': 'Research',    'emoji': '🔬', 'color': Color(0xFF3B82F6)},
  {'name': 'Other',       'emoji': '🌐', 'color': Color(0xFF6B7280)},
];

Color categoryColor(String cat) {
  final match = kCategories.firstWhere(
    (c) => (c['name'] as String).toLowerCase() == cat.toLowerCase(),
    orElse: () => kCategories.last,
  );
  return match['color'] as Color;
}

String categoryEmoji(String cat) {
  final match = kCategories.firstWhere(
    (c) => (c['name'] as String).toLowerCase() == cat.toLowerCase(),
    orElse: () => kCategories.last,
  );
  return match['emoji'] as String;
}

// ── Room message ──────────────────────────────────────────────────────────────

class RoomMessage {
  final int id;
  final int roomId;
  final int userId;
  final String username;
  final String content;
  final String sentAt;

  RoomMessage({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.username,
    required this.content,
    required this.sentAt,
  });

  factory RoomMessage.fromJson(Map<String, dynamic> json) => RoomMessage(
        id: json['id'],
        roomId: json['roomId'],
        userId: json['userId'],
        username: json['username'] ?? '',
        content: json['content'] ?? '',
        sentAt: json['sentAt'] ?? '',
      );
}

// ── Room member ───────────────────────────────────────────────────────────────

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

// ── Focus room ────────────────────────────────────────────────────────────────

class FocusRoom {
  final int id;
  final String name;
  final String emoji;
  final String createdBy;
  final int memberCount;
  final List<RoomMember> members;

  // ── New fields ──────────────────────────────────────────────────────────
  final String category;
  final String? description;
  final int maxMembers;   // 0 = unlimited
  final bool isPrivate;
  final String? inviteCode;
  final bool isFull;

  FocusRoom({
    required this.id,
    required this.name,
    required this.emoji,
    required this.createdBy,
    required this.memberCount,
    required this.members,
    this.category = 'Study',
    this.description,
    this.maxMembers = 0,
    this.isPrivate = false,
    this.inviteCode,
    this.isFull = false,
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
        category: json['category'] ?? 'Study',
        description: json['description'],
        maxMembers: json['maxMembers'] ?? 0,
        isPrivate: json['isPrivate'] ?? false,
        inviteCode: json['inviteCode'],
        isFull: json['isFull'] ?? false,
      );

  /// Capacity label shown on cards: "3/8" or "3/∞"
  String capacityLabel(int current) {
    if (maxMembers == 0) return '$current / ∞';
    return '$current / $maxMembers';
  }
}

// ── Room event (WebSocket) ────────────────────────────────────────────────────

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
