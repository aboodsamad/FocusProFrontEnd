import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../providers/user_provider.dart';
import '../../habits/providers/habit_provider.dart';
import '../../profile/services/activity_log_service.dart';
import '../../coaching/services/coaching_service.dart';
import '../../coaching/models/daily_goal_model.dart';
import '../../challenge/models/daily_challenge_model.dart';
import '../../challenge/services/daily_challenge_service.dart';
import '../../games/hub/models/game_registry.dart';
import '../../books/pages/books_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // ── Stats state (all loaded from real data, never hardcoded) ──────────────
  int _distractingMinutes = 0; // loaded from SharedPreferences; user-editable
  int _streakDays         = 0; // calculated from activity logs
  int _todaySessions      = 0; // calculated from activity logs
  List<DailyGoalModel> _todayGoals = []; // coaching goals

  // ── Daily challenge state ─────────────────────────────────────────────────
  DailyChallengeModel? _challenge;
  bool _challengeLoading = true;
  String? _challengeError;

  late AnimationController _scoreAnimController;
  late Animation<double> _scoreAnim;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _scoreAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _scoreAnim = Tween<double>(begin: 0, end: 0).animate(_scoreAnimController);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animateScore();
      _loadDistractingMinutes();
      _loadStats();
      _loadTodayGoals();
      _loadChallenge();
    });
  }

  void _animateScore() {
    // Use the real focus score — no fallback fakes.
    final score = context.read<UserProvider>().focusScore;
    _scoreAnim = Tween<double>(begin: 0, end: score).animate(
      CurvedAnimation(parent: _scoreAnimController, curve: Curves.easeOutCubic),
    );
    _scoreAnimController.forward();
  }

  /// Loads distracting-minutes from SharedPreferences (user-persisted, not backend).
  Future<void> _loadDistractingMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _distractingMinutes = prefs.getInt('distracting_minutes') ?? 0;
    });
  }

  Future<void> _loadTodayGoals() async {
    final token = await AuthService.getToken() ?? '';
    final goals = await CoachingService.getTodayGoals(token);
    if (!mounted) return;
    setState(() => _todayGoals = goals);
  }

  Future<void> _loadChallenge() async {
    if (!mounted) return;
    setState(() {
      _challengeLoading = true;
      _challengeError = null;
    });
    try {
      final challenge = await DailyChallengeService.getTodayChallenge();
      if (!mounted) return;
      setState(() {
        _challenge = challenge;
        _challengeLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _challengeError = e.toString();
        _challengeLoading = false;
      });
    }
  }

  /// Fetches activity logs and derives streak + today's session count.
  Future<void> _loadStats() async {
    final logs = await ActivityLogService.fetchLogs();
    if (!mounted) return;

    final today     = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Count every activity logged today as one "session"
    final todaySessions = logs.where((l) {
      final d = l.activityDate.toLocal();
      return DateTime(d.year, d.month, d.day) == todayDate;
    }).length;

    // Streak = consecutive days (going back from today) that have ≥1 activity
    final activeDays = logs
        .map((l) {
          final d = l.activityDate.toLocal();
          return DateTime(d.year, d.month, d.day);
        })
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a)); // newest first

    int streak = 0;
    final yesterday = todayDate.subtract(const Duration(days: 1));
    DateTime check = (activeDays.isNotEmpty && activeDays.first == todayDate)
        ? todayDate
        : yesterday;
    for (final day in activeDays) {
      if (day == check) {
        streak++;
        check = check.subtract(const Duration(days: 1));
      } else if (day.isBefore(check)) {
        break; // gap in days — streak ends
      }
    }

    setState(() {
      _todaySessions = todaySessions;
      _streakDays    = streak;
    });
  }

  @override
  void dispose() {
    _scoreAnimController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Log out',
            style: TextStyle(color: AppColors.onSurface,
                fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to log out?',
            style: TextStyle(color: AppColors.onSurfaceVariant)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await AuthService.logout();
    if (!mounted) return;
    await context.read<UserProvider>().logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
  }

  void _editUsage() {
    showDialog<int>(
      context: context,
      builder: (_) {
        final ctl = TextEditingController(text: '$_distractingMinutes');
        return AlertDialog(
          backgroundColor: AppColors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Distracted Minutes',
              style: TextStyle(color: AppColors.onSurface,
                  fontWeight: FontWeight.bold)),
          content: TextField(
            controller: ctl,
            keyboardType: TextInputType.number,
            style: TextStyle(color: AppColors.onSurface),
            decoration: InputDecoration(
              hintText: 'Minutes on distracting apps',
              hintStyle: TextStyle(color: AppColors.onSurfaceVariant),
              filled: true,
              fillColor: AppColors.surfaceContainerLow,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.outlineVariant)),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel',
                    style: TextStyle(color: AppColors.onSurfaceVariant))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              onPressed: () =>
                  Navigator.pop(context, int.tryParse(ctl.text) ?? 0),
              child: const Text('Save'),
            ),
          ],
        );
      },
    ).then((v) async {
      if (v != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('distracting_minutes', v);
        if (mounted) setState(() => _distractingMinutes = v);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    if (user.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    final score = user.focusScore;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          _buildHeader(user),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcomeSection(user),
                  _buildFocusScoreRing(score),
                  _buildStatsRow(),
                  _buildBentoGrid(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(UserProvider user) {
    return Container(
      color: const Color(0xFFF0FBF5),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12,
        left: 16,
        right: 16,
      ),
      child: Row(children: [
        // Avatar
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/profile'),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryContainer,
              border: Border.all(color: AppColors.primaryContainer, width: 2),
            ),
            child: Center(
              child: Text(
                user.displayInitial,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // App name
        Text(
          'FocusPro',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        // Settings icon
        GestureDetector(
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Settings (TODO)'))),
          child: Icon(Icons.settings_outlined,
              color: AppColors.primary, size: 24),
        ),
        const SizedBox(width: 8),
        // Logout
        GestureDetector(
          onTap: _logout,
          child: Icon(Icons.logout_rounded,
              color: AppColors.onSurfaceVariant, size: 22),
        ),
      ]),
    );
  }

  // ── Welcome section ───────────────────────────────────────────────────────
  Widget _buildWelcomeSection(UserProvider user) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          '$_greeting, ${user.name}',
          style: TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Ready for deep work?',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 36,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
      ]),
    );
  }

  // ── Focus Score Ring ──────────────────────────────────────────────────────
  Widget _buildFocusScoreRing(double score) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_scoreAnim, _pulseAnim]),
          builder: (_, __) {
            return SizedBox(
              width: 200,
              height: 200,
              child: Stack(alignment: Alignment.center, children: [
                CustomPaint(
                  size: const Size(200, 200),
                  painter: _DeepFocusRingPainter(
                      progress: _scoreAnim.value / 100),
                ),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    _scoreAnim.value.toStringAsFixed(0),
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 72,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    'FOCUS SCORE',
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ]),
              ]),
            );
          },
        ),
      ),
    );
  }

  // ── Stats row ─────────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Expanded(child: _StatPill(
          icon: Icons.local_fire_department,
          iconColor: Colors.deepOrange,
          value: '$_streakDays days',
          label: 'STREAK',
        )),
        const SizedBox(width: 10),
        Expanded(child: _StatPill(
          icon: Icons.history_rounded,
          iconColor: AppColors.tertiaryContainer,
          value: '$_todaySessions',
          label: 'SESSIONS',
        )),
        const SizedBox(width: 10),
        Expanded(child: GestureDetector(
          onTap: _editUsage,
          child: _StatPill(
            icon: Icons.timer_off_outlined,
            iconColor: AppColors.error,
            value: '${_distractingMinutes}m',
            label: 'DISTRACTIONS',
          ),
        )),
      ]),
    );
  }

  // ── Bento grid ────────────────────────────────────────────────────────────
  Widget _buildBentoGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(children: [
        // Daily Challenge — full width, shown prominently first
        _buildDailyChallengeCard(),
        const SizedBox(height: 12),
        // Focus Room — full width
        _buildFocusRoomCard(),
        const SizedBox(height: 12),
        // Games + Books — half width
        Row(children: [
          Expanded(child: _buildGameCard()),
          const SizedBox(width: 12),
          Expanded(child: _buildBookCard()),
        ]),
        const SizedBox(height: 12),
        // Habits — full width
        _buildHabitsCard(),
        const SizedBox(height: 12),
        // AI Coach — full width
        _buildCoachingCard(),
      ]),
    );
  }

  // ── Daily Challenge Card ──────────────────────────────────────────────────

  static const Map<String, Color> _weaknessColors = {
    'memory':    Color(0xFF7B6FFF),
    'attention': Color(0xFF10B981),
    'speed':     Color(0xFFF59E0B),
    'logic':     Color(0xFF6366F1),
    'reading':   Color(0xFFF97316),
  };

  static const Map<String, IconData> _weaknessIcons = {
    'memory':    Icons.grid_on_rounded,
    'attention': Icons.palette_outlined,
    'speed':     Icons.bolt_rounded,
    'logic':     Icons.apps_rounded,
    'reading':   Icons.menu_book_outlined,
  };

  Widget _buildDailyChallengeCard() {
    // ── Loading ──────────────────────────────────────────────────────────────
    if (_challengeLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const SizedBox(
          height: 80,
          child: Center(
            child: CircularProgressIndicator(
              color: AppColors.primaryFixed,
              strokeWidth: 2.5,
            ),
          ),
        ),
      );
    }

    // ── Error ────────────────────────────────────────────────────────────────
    if (_challengeError != null || _challenge == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Could not load today\'s challenge.',
                style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: _loadChallenge,
              child: Text('Retry',
                  style: TextStyle(color: AppColors.primary,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    // ── Loaded ───────────────────────────────────────────────────────────────
    final challenge = _challenge!;
    final areaColor = _weaknessColors[challenge.weaknessArea]
        ?? const Color(0xFF7B6FFF);
    final areaIcon  = _weaknessIcons[challenge.weaknessArea]
        ?? Icons.grid_on_rounded;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ───────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: areaColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: areaColor.withOpacity(0.5)),
                ),
                child: Icon(areaIcon, color: areaColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Today's Challenge",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Resets at midnight',
                      style: TextStyle(
                          color: AppColors.onPrimaryContainer, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (challenge.isCompleted)
                _StatusPill(label: 'Done ✓', color: Colors.green.shade400)
              else if (challenge.isExpired)
                _StatusPill(
                    label: 'Expired',
                    color: AppColors.onPrimaryContainer),
            ],
          ),
          const SizedBox(height: 12),
          // ── Title ────────────────────────────────────────────────────────
          Text(
            challenge.challengeTitle,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15),
          ),
          const SizedBox(height: 6),
          // ── Description ──────────────────────────────────────────────────
          Text(
            challenge.challengeDescription,
            style: TextStyle(
                color: Colors.grey[300], fontSize: 13, height: 1.5),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          // ── Action buttons ────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildChallengeActionButton(challenge, areaColor),
              ),
              if (!challenge.isCompleted && !challenge.isExpired) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: _buildHintButton(),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeActionButton(
      DailyChallengeModel challenge, Color areaColor) {
    final bool disabled = challenge.isCompleted || challenge.isExpired;
    final String label = disabled
        ? (challenge.isCompleted ? 'Completed' : 'Expired')
        : _challengeActionLabel(challenge);

    return GestureDetector(
      onTap: disabled ? null : () => _onChallengeAction(challenge),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          gradient: disabled
              ? null
              : LinearGradient(
                  colors: [areaColor, AppColors.primary],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          color: disabled ? Colors.white.withOpacity(0.07) : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: disabled
                  ? AppColors.onPrimaryContainer
                  : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  String _challengeActionLabel(DailyChallengeModel challenge) {
    switch (challenge.challengeType) {
      case 'GAME':
        final game = challenge.targetGameType != null
            ? GameRegistry.findById(challenge.targetGameType!)
            : null;
        return 'Play ${game?.title ?? 'Game'}';
      case 'BOOK':
        return 'Open Reader';
      default:
        return 'Mark Done';
    }
  }

  Future<void> _onChallengeAction(DailyChallengeModel challenge) async {
    switch (challenge.challengeType) {
      case 'GAME':
        final gameType = challenge.targetGameType;
        if (gameType == null) return;
        final page = GameRegistry.pageFor(gameType);
        if (page == null) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => page),
        );
        // After returning from the game, mark challenge complete
        try {
          await DailyChallengeService.completeChallenge(challenge.id);
        } catch (_) {}
        await _loadChallenge();
        break;

      case 'BOOK':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BooksPage()),
        );
        break;

      default: // CUSTOM → Mark Done
        try {
          await DailyChallengeService.completeChallenge(challenge.id);
        } catch (_) {}
        await _loadChallenge();
    }
  }

  Widget _buildHintButton() {
    return GestureDetector(
      onTap: _showWeaknessHintSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.onPrimaryContainer),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit_outlined,
                color: AppColors.onPrimaryContainer, size: 14),
            const SizedBox(width: 4),
            Text(
              'I feel weak at...',
              style: TextStyle(
                  color: AppColors.onPrimaryContainer,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _showWeaknessHintSheet() {
    final controller = TextEditingController();
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.onPrimaryContainer,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Tell the AI what to focus on',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  "Tomorrow's challenge will be tailored based on what you share",
                  style: TextStyle(
                      color: AppColors.onPrimaryContainer, fontSize: 13),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText:
                        'e.g. I struggle with memory games, I haven\'t read in weeks, my focus drops after lunch...',
                    hintStyle: TextStyle(
                        color: AppColors.onPrimaryContainer.withOpacity(0.6),
                        fontSize: 13),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: AppColors.onPrimaryContainer.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.primaryFixed, width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: AppColors.onPrimaryContainer.withOpacity(0.3)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: submitting
                      ? null
                      : () async {
                          final text = controller.text.trim();
                          if (text.isEmpty) return;
                          setSheetState(() => submitting = true);
                          try {
                            await DailyChallengeService.submitHint(text);
                            if (!mounted) return;
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    "Got it — tomorrow's challenge will reflect this"),
                              ),
                            );
                          } catch (_) {
                            setSheetState(() => submitting = false);
                          }
                        },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.secondary, AppColors.primary],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Update',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Focus Room Card ───────────────────────────────────────────────────────
  Widget _buildFocusRoomCard() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/rooms'),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Icon(Icons.sensor_door_outlined,
                  color: AppColors.primaryFixed, size: 36),
              const Spacer(),
              OutlinedButton(
                onPressed: () => Navigator.pushNamed(context, '/rooms'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.primaryFixed,
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  shape: StadiumBorder(),
                ),
                child: Text('Enter Now',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text(
                'Start Focus Room',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Join others in a quiet session.',
                style: TextStyle(
                    color: AppColors.onPrimaryContainer, fontSize: 13),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildGameCard() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/games'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 10,
                offset: const Offset(0, 2))
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.extension_outlined,
                color: AppColors.secondary, size: 30),
            const SizedBox(height: 12),
            const Text('Play a Game',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.onSurface)),
            const SizedBox(height: 4),
            Text('2–6 min sessions',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildBookCard() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/books'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 10,
                offset: const Offset(0, 2))
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.menu_book_outlined,
                color: AppColors.tertiaryContainer, size: 30),
            const SizedBox(height: 12),
            const Text('Read a Book',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.onSurface)),
            const SizedBox(height: 4),
            Text('TTS / Reader',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitsCard() {
    return Consumer<HabitProvider>(
      builder: (context, provider, _) {
        final remaining = provider.totalCount - provider.doneCount;
        return GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/habits'),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(children: [
              Icon(Icons.task_alt_outlined,
                  color: AppColors.secondary, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('My Habits',
                        style: TextStyle(
                            color: AppColors.onSecondaryFixedVariant,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      provider.isLoading
                          ? 'Loading...'
                          : '$remaining task${remaining == 1 ? '' : 's'} remaining for today',
                      style: TextStyle(
                          color: AppColors.onSecondaryContainer,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.onSecondaryFixedVariant),
            ]),
          ),
        );
      },
    );
  }
  Widget _buildCoachingCard() {
    final goalCount = _todayGoals.length;
    final doneCount = _todayGoals.where((g) => g.status == 'DONE').length;
    final subtitle = goalCount == 0
        ? 'Start your day'
        : '$doneCount / $goalCount goals done today';
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/coaching'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 10,
                offset: const Offset(0, 2))
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(children: [
          Icon(Icons.psychology_outlined,
              color: AppColors.primary, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI Daily Coach',
                    style: TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        color: AppColors.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.onSurfaceVariant),
        ]),
      ),
    );
  }
}

// ── Status pill (Done / Expired) ──────────────────────────────────────────
class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ── Deep Focus Ring Painter ────────────────────────────────────────────────
class _DeepFocusRingPainter extends CustomPainter {
  final double progress;
  _DeepFocusRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - stroke) / 2;

    // Track ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.surfaceContainerHigh
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    // Progress arc
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = AppColors.primaryContainer
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_DeepFocusRingPainter old) => old.progress != progress;
}

// ── Stat pill widget ──────────────────────────────────────────────────────
class _StatPill extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatPill({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8)),
        ],
      ),
    );
  }
}
