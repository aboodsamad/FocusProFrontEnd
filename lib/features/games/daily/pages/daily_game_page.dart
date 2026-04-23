import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../models/daily_game_models.dart';
import '../services/daily_game_service.dart';
import '../../visual_nback/pages/visual_nback_page.dart';
import '../../go_no_go/pages/go_no_go_page.dart';
import '../../flanker_task/pages/flanker_task_page.dart';

class DailyGamePage extends StatefulWidget {
  const DailyGamePage({super.key});

  @override
  State<DailyGamePage> createState() => _DailyGamePageState();
}

class _DailyGamePageState extends State<DailyGamePage> {
  DailyGameStatus? _status;
  DailyGameLeaderboard? _leaderboard;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        DailyGameService.getTodayStatus(),
        DailyGameService.getLeaderboard(),
      ]);
      if (!mounted) return;
      setState(() {
        _status      = results[0] as DailyGameStatus;
        _leaderboard = results[1] as DailyGameLeaderboard;
        _loading     = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Color get _gameColor {
    switch (_status?.gameType) {
      case 'visual_nback':  return const Color(0xFF7B6FFF);
      case 'go_no_go':      return const Color(0xFF10B981);
      case 'flanker_task':  return const Color(0xFF06B6D4);
      default:              return AppColors.primary;
    }
  }

  void _openDailyGame() {
    final gameType = _status?.gameType;
    if (gameType == null) return;

    Future<void> handleScore(int score, int time, bool completed, int level, int mistakes) async {
      try {
        await DailyGameService.submitScore(
          score:             score,
          timePlayedSeconds: time,
          completed:         completed,
          levelReached:      level,
          mistakes:          mistakes,
        );
      } catch (e) {
        if (mounted && e.toString().contains('Already played')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Already submitted today\'s score')),
          );
        }
      }
      if (mounted) await _loadData();
    }

    Widget page;
    switch (gameType) {
      case 'visual_nback':
        page = VisualNBackPage(onScoreSubmitted: handleScore);
        break;
      case 'go_no_go':
        page = GoNoGoPage(onScoreSubmitted: handleScore);
        break;
      case 'flanker_task':
        page = FlankerTaskPage(onScoreSubmitted: handleScore);
        break;
      default:
        return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080D1A),
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white70, size: 16),
          ),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Daily Game',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Text('Resets at midnight UTC · ${now.day}/${now.month}',
              style: TextStyle(color: Colors.grey[600], fontSize: 11)),
        ]),
      ]),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error!, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        const SizedBox(height: 16),
        TextButton(onPressed: _loadData, child: const Text('Retry')),
      ]));
    }

    final status = _status!;
    final leaderboard = _leaderboard!;
    final gameColor = _gameColor;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _buildTodayCard(status, gameColor),
        )),
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: _buildLeaderboard(leaderboard, gameColor),
        )),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _buildTodayCard(DailyGameStatus status, Color gameColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1624),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gameColor.withOpacity(0.4), width: 1.5),
        boxShadow: [BoxShadow(color: gameColor.withOpacity(0.15), blurRadius: 20)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text("TODAY'S CHALLENGE",
              style: TextStyle(color: gameColor, fontSize: 10,
                  fontWeight: FontWeight.bold, letterSpacing: 1)),
          const Spacer(),
          if (status.hasPlayed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Played ✓',
                  style: TextStyle(color: Color(0xFF10B981), fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
        ]),
        const SizedBox(height: 12),
        Text(status.gameTitle,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(status.gameDescription,
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey[500], fontSize: 13, height: 1.4)),
        const SizedBox(height: 16),
        Row(children: [
          Text('${status.totalPlayers} playing today',
              style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const Spacer(),
          Text(status.hasPlayed
              ? 'Your rank: #${status.userRank ?? '?'}'
              : 'Your rank: —',
              style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ]),
        const SizedBox(height: 16),
        status.hasPlayed
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1624),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: gameColor.withOpacity(0.3)),
                ),
                child: Center(child: Text(
                  'Played ✓   Score: ${status.userScore ?? 0}',
                  style: TextStyle(color: gameColor, fontWeight: FontWeight.bold, fontSize: 14),
                )),
              )
            : GestureDetector(
                onTap: _openDailyGame,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      gameColor,
                      Color.lerp(gameColor, Colors.black, 0.2)!,
                    ]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(child: Text(
                    'Play Now  →',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  )),
                ),
              ),
      ]),
    );
  }

  Widget _buildLeaderboard(DailyGameLeaderboard leaderboard, Color gameColor) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Today\'s Leaderboard',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      if (leaderboard.entries.isEmpty)
        Center(child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text('No scores yet — be the first to play!',
              style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        ))
      else ...[
        ...leaderboard.entries.take(20).map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildEntryRow(e, gameColor),
        )),
        if (leaderboard.currentUserEntry != null &&
            (leaderboard.currentUserEntry!.rank) > 20) ...[
          Divider(color: Colors.white.withOpacity(0.06), thickness: 1),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text('Your Position',
                style: TextStyle(color: Colors.grey[600], fontSize: 11,
                    letterSpacing: 0.5, fontWeight: FontWeight.w600)),
          ),
          _buildEntryRow(leaderboard.currentUserEntry!, gameColor),
        ],
      ],
    ]);
  }

  Widget _buildEntryRow(LeaderboardEntry entry, Color gameColor) {
    Color rankBg;
    switch (entry.rank) {
      case 1: rankBg = const Color(0xFFFFD700); break;
      case 2: rankBg = const Color(0xFFAFAFAF); break;
      case 3: rankBg = const Color(0xFFCD7F32); break;
      default: rankBg = Colors.white.withOpacity(0.08);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: entry.isCurrentUser
            ? AppColors.primary.withOpacity(0.08)
            : const Color(0xFF0F1624),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: entry.isCurrentUser
              ? AppColors.primary.withOpacity(0.3)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: rankBg, shape: BoxShape.circle),
          child: Center(child: Text('#${entry.rank}',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(entry.displayName,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500))),
        if (entry.isCurrentUser) ...[
          Text('you', style: TextStyle(color: AppColors.primary,
              fontSize: 11, fontStyle: FontStyle.italic)),
          const SizedBox(width: 8),
        ],
        Text('${entry.score} pts',
            style: TextStyle(color: gameColor, fontSize: 14, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}
