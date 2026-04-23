class DailyGameStatus {
  final String gameType;
  final String gameTitle;
  final String gameDescription;
  final DateTime gameDate;
  final bool hasPlayed;
  final int? userScore;
  final int? userRank;
  final int totalPlayers;

  const DailyGameStatus({
    required this.gameType,
    required this.gameTitle,
    required this.gameDescription,
    required this.gameDate,
    required this.hasPlayed,
    required this.totalPlayers,
    this.userScore,
    this.userRank,
  });

  factory DailyGameStatus.fromJson(Map<String, dynamic> json) {
    return DailyGameStatus(
      gameType:        json['gameType'] as String? ?? '',
      gameTitle:       json['gameTitle'] as String? ?? '',
      gameDescription: json['gameDescription'] as String? ?? '',
      gameDate:        DateTime.tryParse(json['gameDate'] as String? ?? '') ?? DateTime.now(),
      hasPlayed:       json['hasPlayed'] as bool? ?? false,
      userScore:       json['userScore'] as int?,
      userRank:        json['userRank'] as int?,
      totalPlayers:    json['totalPlayers'] as int? ?? 0,
    );
  }
}

class LeaderboardEntry {
  final int rank;
  final int score;
  final String displayName;
  final String username;
  final bool isCurrentUser;

  const LeaderboardEntry({
    required this.rank,
    required this.score,
    required this.displayName,
    required this.username,
    required this.isCurrentUser,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank:          json['rank'] as int? ?? 0,
      score:         json['score'] as int? ?? 0,
      displayName:   json['displayName'] as String? ?? '',
      username:      json['username'] as String? ?? '',
      isCurrentUser: json['isCurrentUser'] as bool? ?? false,
    );
  }
}

class DailyGameLeaderboard {
  final String gameType;
  final DateTime gameDate;
  final List<LeaderboardEntry> entries;
  final LeaderboardEntry? currentUserEntry;

  const DailyGameLeaderboard({
    required this.gameType,
    required this.gameDate,
    required this.entries,
    this.currentUserEntry,
  });

  factory DailyGameLeaderboard.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'] as List<dynamic>? ?? [];
    final entries = rawEntries
        .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
        .toList();

    LeaderboardEntry? current;
    if (json['currentUserEntry'] != null) {
      current = LeaderboardEntry.fromJson(json['currentUserEntry'] as Map<String, dynamic>);
    }

    return DailyGameLeaderboard(
      gameType:         json['gameType'] as String? ?? '',
      gameDate:         DateTime.tryParse(json['gameDate'] as String? ?? '') ?? DateTime.now(),
      entries:          entries,
      currentUserEntry: current,
    );
  }
}
