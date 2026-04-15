class CoachingMessage {
  final String role; // "user" or "ai"
  final String content;
  final DateTime timestamp;

  const CoachingMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });
}
