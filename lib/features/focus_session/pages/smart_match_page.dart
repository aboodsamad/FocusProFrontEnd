import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/focus_room.dart';
import '../models/room_match_result.dart';
import '../services/focus_room_service.dart';
import 'focus_room_session_page.dart';

class SmartMatchPage extends StatefulWidget {
  const SmartMatchPage({Key? key}) : super(key: key);

  @override
  State<SmartMatchPage> createState() => _SmartMatchPageState();
}

class _SmartMatchPageState extends State<SmartMatchPage> {
  final TextEditingController _goalCtl = TextEditingController();
  bool _loading = false;
  List<RoomMatchResult>? _results;
  String? _submittedGoal;

  @override
  void dispose() {
    _goalCtl.dispose();
    super.dispose();
  }

  Future<void> _findMatch() async {
    final goal = _goalCtl.text.trim();
    if (goal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe what you want to work on.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final results = await FocusRoomService.findMatch(goal);
      if (mounted) {
        setState(() {
          _results = results;
          _submittedGoal = goal;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _goBackToInput() {
    setState(() {
      _results = null;
      _submittedGoal = null;
    });
  }

  Future<void> _joinRoom(RoomMatchResult match) async {
    final room = FocusRoom(
      id: match.roomId!,
      name: match.roomName,
      emoji: match.roomEmoji,
      createdBy: '',
      memberCount: match.memberCount,
      members: const [],
    );
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FocusRoomSessionPage(room: room),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: _results != null ? _buildResults() : _buildInput(),
      ),
    );
  }

  // ── STATE 1: Goal input ───────────────────────────────────────────────────

  Widget _buildInput() {
    return Column(
      children: [
        _buildAppBar(onBack: () => Navigator.pop(context)),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Find your match',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tell us what you\'re working on',
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 36),
                TextField(
                  controller: _goalCtl,
                  style: const TextStyle(
                      color: AppColors.onSurface, fontSize: 15),
                  maxLines: 3,
                  minLines: 2,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText:
                        'e.g. Studying for my calculus exam, working on my Flutter project...',
                    hintStyle: TextStyle(
                      color: AppColors.onSurfaceVariant.withOpacity(0.55),
                      fontSize: 14,
                      height: 1.5,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: AppColors.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: AppColors.secondary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
              24, 0, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: _loading
              ? Column(mainAxisSize: MainAxisSize.min, children: const [
                  SizedBox(height: 8),
                  CircularProgressIndicator(color: AppColors.secondary),
                  SizedBox(height: 12),
                  Text(
                    'AI is finding your match...',
                    style: TextStyle(
                        color: AppColors.onSurfaceVariant, fontSize: 14),
                  ),
                  SizedBox(height: 16),
                ])
              : SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      shape: const StadiumBorder(),
                      elevation: 0,
                    ),
                    onPressed: _findMatch,
                    child: const Text(
                      'Find Match',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  // ── STATE 2: Match results ─────────────────────────────────────────────────

  Widget _buildResults() {
    final results = _results!;
    return Column(
      children: [
        _buildAppBar(onBack: _goBackToInput),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your matches',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _submittedGoal ?? '',
                style: const TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.4,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: results.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🏠', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      const Text(
                        'No active rooms right now',
                        style: TextStyle(
                            color: AppColors.onSurface,
                            fontSize: 17,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          shape: const StadiumBorder(),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.pop(context, 'create'),
                        child: const Text('Create one'),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final match = results[i];
                    if (match.isNewRoomSuggestion) {
                      return _NewRoomCard(
                        matchReason: match.matchReason,
                        onTap: () => Navigator.pop(context, 'create'),
                      );
                    }
                    return _MatchCard(
                      match: match,
                      onTap: () => _joinRoom(match),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── Shared app bar ────────────────────────────────────────────────────────

  Widget _buildAppBar({required VoidCallback onBack}) {
    return Container(
      color: Colors.green.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.primary, size: 16),
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'Smart Match',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ]),
    );
  }
}

// ── New room suggestion card ───────────────────────────────────────────────────

class _NewRoomCard extends StatelessWidget {
  final String matchReason;
  final VoidCallback onTap;

  const _NewRoomCard({required this.matchReason, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.secondary.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add_rounded,
                  color: AppColors.onSecondary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create a new room',
                    style: TextStyle(
                      color: AppColors.onPrimaryContainer,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    matchReason,
                    style: const TextStyle(
                      color: AppColors.onPrimaryContainer,
                      fontSize: 13,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.onPrimaryContainer, size: 14),
          ],
        ),
      ),
    );
  }
}

// ── Match result card ──────────────────────────────────────────────────────────

class _MatchCard extends StatelessWidget {
  final RoomMatchResult match;
  final VoidCallback onTap;

  const _MatchCard({required this.match, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: emoji + name + member count + score pill
            Row(
              children: [
                Text(match.roomEmoji,
                    style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    match.roomName,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '👥 ${match.memberCount}',
                    style: const TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _ScorePill(score: match.matchScore),
              ],
            ),
            const SizedBox(height: 10),

            // Match reason
            Text(
              match.matchReason,
              style: const TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 13,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Member goal chips (up to 3)
            if (match.memberGoals.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: match.memberGoals.take(3).map((goal) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.outlineVariant, width: 0.8),
                    ),
                    child: Text(
                      '📍 $goal',
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 12),

            // Join button
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Join',
                  style: TextStyle(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Score pill ─────────────────────────────────────────────────────────────────

class _ScorePill extends StatelessWidget {
  final double score;

  const _ScorePill({required this.score});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (score >= 75) {
      bg = const Color(0xFFD1FAE5);
      fg = const Color(0xFF065F46);
    } else if (score >= 50) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFF92400E);
    } else {
      bg = AppColors.surfaceContainerHigh;
      fg = AppColors.onSurfaceVariant;
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${score.toStringAsFixed(0)}% match',
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
