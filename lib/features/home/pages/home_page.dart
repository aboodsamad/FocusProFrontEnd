import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/update_service.dart';
import '../providers/user_provider.dart';
import '../../habits/providers/habit_provider.dart';
import '../../profile/services/activity_log_service.dart';
import '../../coaching/services/coaching_service.dart';
import '../../coaching/models/daily_goal_model.dart';
import '../../challenge/models/daily_challenge_model.dart';
import '../../challenge/services/daily_challenge_service.dart';
import '../../games/hub/models/game_registry.dart';
import '../../books/pages/books_page.dart';
import '../../lockin/models/lock_in_session_model.dart';
import '../../lockin/services/lock_in_service.dart';
import '../../lockin/pages/lock_in_page.dart';
import '../../lockin/pages/schedules_page.dart';
import '../../books/pages/book_detail_page.dart';
import '../../books/services/book_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // ── Stats state ───────────────────────────────────────────────────────────
  int _distractingMinutes = 0;
  int _streakDays         = 0;
  int _todaySessions      = 0;
  List<DailyGoalModel> _todayGoals = [];

  // ── Lock-In state ─────────────────────────────────────────────────────────
  LockInSessionModel? _activeSession;

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
      _loadActiveSession();
      UpdateService.checkForUpdate(context);
    });
  }

  void _animateScore() {
    final score = context.read<UserProvider>().focusScore;
    _scoreAnim = Tween<double>(begin: 0, end: score).animate(
      CurvedAnimation(parent: _scoreAnimController, curve: Curves.easeOutCubic),
    );
    _scoreAnimController.forward();
  }

  Future<void> _loadDistractingMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _distractingMinutes = prefs.getInt('distracting_minutes') ?? 0);
  }

  Future<void> _loadActiveSession() async {
    final session = await LockInService.getActiveSession();
    if (!mounted) return;
    setState(() => _activeSession = session);
  }

  Future<void> _loadTodayGoals() async {
    final token = await AuthService.getToken() ?? '';
    final goals = await CoachingService.getTodayGoals(token);
    if (!mounted) return;
    setState(() => _todayGoals = goals);
  }

  Future<void> _loadChallenge() async {
    if (!mounted) return;
    setState(() { _challengeLoading = true; _challengeError = null; });
    try {
      final challenge = await DailyChallengeService.getTodayChallenge();
      if (!mounted) return;
      setState(() { _challenge = challenge; _challengeLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _challengeError = e.toString(); _challengeLoading = false; });
    }
  }

  Future<void> _loadStats() async {
    final logs = await ActivityLogService.fetchLogs();
    if (!mounted) return;
    final today     = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final todaySessions = logs.where((l) {
      final d = l.activityDate.toLocal();
      return DateTime(d.year, d.month, d.day) == todayDate;
    }).length;
    final activeDays = logs.map((l) {
      final d = l.activityDate.toLocal();
      return DateTime(d.year, d.month, d.day);
    }).toSet().toList()..sort((a, b) => b.compareTo(a));
    int streak = 0;
    final yesterday = todayDate.subtract(const Duration(days: 1));
    DateTime check = (activeDays.isNotEmpty && activeDays.first == todayDate)
        ? todayDate : yesterday;
    for (final day in activeDays) {
      if (day == check) { streak++; check = check.subtract(const Duration(days: 1)); }
      else if (day.isBefore(check)) break;
    }
    setState(() { _todaySessions = todaySessions; _streakDays = streak; });
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
        title: const Text('Log out',
            style: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out?',
            style: TextStyle(color: AppColors.onSurfaceVariant)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
          title: const Text('Distracted Minutes',
              style: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: ctl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.onSurface),
            decoration: InputDecoration(
              hintText: 'Minutes on distracting apps',
              hintStyle: const TextStyle(color: AppColors.onSurfaceVariant),
              filled: true, fillColor: AppColors.surfaceContainerLow,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.outlineVariant)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: AppColors.onSurfaceVariant))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () => Navigator.pop(context, int.tryParse(ctl.text) ?? 0),
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

  // ── Challenge helpers (unchanged logic) ───────────────────────────────────

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

  String _challengeActionLabel(DailyChallengeModel challenge) {
    switch (challenge.challengeType) {
      case 'GAME':
        final game = challenge.targetGameType != null
            ? GameRegistry.findById(challenge.targetGameType!) : null;
        return 'Play ${game?.title ?? 'Game'}';
      case 'BOOK': return 'Open Reader';
      default:     return 'Mark Done';
    }
  }

  Future<void> _onChallengeAction(DailyChallengeModel challenge) async {
    switch (challenge.challengeType) {
      case 'GAME':
        final gameType = challenge.targetGameType;
        if (gameType == null) return;
        final page = GameRegistry.pageFor(gameType);
        if (page == null) return;
        await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
        try { await DailyChallengeService.completeChallenge(challenge.id); } catch (_) {}
        await _loadChallenge();
        break;
      case 'BOOK':
        if (challenge.targetBookId != null) {
          final book = await BookService.getBookById(challenge.targetBookId!);
          if (!mounted) return;
          if (book != null) {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailPage(book: book)));
          } else {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const BooksPage()));
          }
        } else {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const BooksPage()));
        }
        break;
      default:
        try { await DailyChallengeService.completeChallenge(challenge.id); } catch (_) {}
        await _loadChallenge();
    }
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
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: AppColors.onPrimaryContainer, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                const Text('Tell the AI what to focus on',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text("Tomorrow's challenge will be tailored based on what you share",
                    style: TextStyle(color: AppColors.onPrimaryContainer, fontSize: 13)),
                const SizedBox(height: 18),
                TextField(
                  controller: controller, maxLines: 3,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. I struggle with memory games...',
                    hintStyle: TextStyle(color: AppColors.onPrimaryContainer.withOpacity(0.6), fontSize: 13),
                    filled: true, fillColor: Colors.white.withOpacity(0.08),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.onPrimaryContainer.withOpacity(0.3))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primaryFixed, width: 1.5)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.onPrimaryContainer.withOpacity(0.3))),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: submitting ? null : () async {
                    final text = controller.text.trim();
                    if (text.isEmpty) return;
                    setSheetState(() => submitting = true);
                    try {
                      await DailyChallengeService.submitHint(text);
                      if (!mounted) return;
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Challenge updated based on your input!')),
                      );
                      _loadChallenge();
                    } catch (_) { setSheetState(() => submitting = false); }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.secondary, AppColors.primary],
                          begin: Alignment.centerLeft, end: Alignment.centerRight),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(child: submitting
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Update', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    if (user.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    final score = user.focusScore;

    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: _buildBottomNav(),
      body: Column(
        children: [
          _buildHeroSection(user, score),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_activeSession != null) _buildActiveBanner(),

                  const SizedBox(height: 20),
                  _buildSectionHeader("Today's Mission"),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildDailyChallengeCard(),
                  ),

                  const SizedBox(height: 24),
                  _buildSectionHeader('Features'),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildFeatureGrid(),
                  ),

                  const SizedBox(height: 24),
                  _buildSectionHeader('Your Progress'),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(children: [
                      _buildCoachingCard(),
                      const SizedBox(height: 10),
                      _buildHabitsCard(),
                    ]),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom Navigation Bar ─────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
            blurRadius: 16, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.home_rounded, label: 'Home', selected: true, onTap: () {}),
              _NavItem(icon: Icons.extension_outlined, label: 'Games', selected: false,
                  onTap: () => Navigator.pushNamed(context, '/games')),
              _NavItem(icon: Icons.psychology_outlined, label: 'Coach', selected: false,
                  onTap: () => Navigator.pushNamed(context, '/coaching')),
              _NavItem(icon: Icons.task_alt_outlined, label: 'Habits', selected: false,
                  onTap: () => Navigator.pushNamed(context, '/habits')),
              _NavItem(icon: Icons.person_outline_rounded, label: 'Profile', selected: false,
                  onTap: () => Navigator.pushNamed(context, '/profile')),
            ],
          ),
        ),
      ),
    );
  }

  // ── Hero Section — compact: ring on left, stats on right ─────────────────
  Widget _buildHeroSection(UserProvider user, double score) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryContainer],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Top bar ────────────────────────────────────────────────────
              Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/profile'),
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.12),
                      border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
                    ),
                    child: Center(
                      child: Text(user.displayInitial,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_greeting,
                      style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11)),
                  Text(user.name ?? 'Focus Pro',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                ]),
                const Spacer(),
                GestureDetector(
                  onTap: _logout,
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.logout_rounded, color: Colors.white, size: 16),
                  ),
                ),
              ]),

              const SizedBox(height: 16),

              // ── Ring (left) + Stats (right) ────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Score ring — 130 px
                  AnimatedBuilder(
                    animation: Listenable.merge([_scoreAnim, _pulseAnim]),
                    builder: (_, __) => SizedBox(
                      width: 130, height: 130,
                      child: Stack(alignment: Alignment.center, children: [
                        CustomPaint(
                          size: const Size(130, 130),
                          painter: _DeepFocusRingPainter(progress: _scoreAnim.value / 100),
                        ),
                        Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(
                            _scoreAnim.value.toStringAsFixed(0),
                            style: const TextStyle(color: Colors.white,
                                fontSize: 42, fontWeight: FontWeight.w900, height: 1.0),
                          ),
                          const SizedBox(height: 2),
                          Text('SCORE',
                              style: TextStyle(color: Colors.white.withOpacity(0.5),
                                  fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 2)),
                        ]),
                      ]),
                    ),
                  ),

                  const SizedBox(width: 20),

                  // Stats column
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildStatRow(
                          icon: Icons.local_fire_department,
                          iconColor: const Color(0xFFFF8A65),
                          value: '$_streakDays',
                          label: 'Day Streak',
                        ),
                        const SizedBox(height: 10),
                        Container(height: 1, color: Colors.white.withOpacity(0.1)),
                        const SizedBox(height: 10),
                        _buildStatRow(
                          icon: Icons.bolt_rounded,
                          iconColor: AppColors.primaryFixed,
                          value: '$_todaySessions',
                          label: 'Sessions Today',
                        ),
                        const SizedBox(height: 10),
                        Container(height: 1, color: Colors.white.withOpacity(0.1)),
                        const SizedBox(height: 10),
                        _buildStatRow(
                          icon: Icons.timer_off_outlined,
                          iconColor: AppColors.primaryFixedDim,
                          value: '${_distractingMinutes}m',
                          label: 'Distracted',
                          onTap: _editUsage,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(children: [
        Icon(icon, color: iconColor, size: 17),
        const SizedBox(width: 8),
        Text(value,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
        if (onTap != null) ...[
          const SizedBox(width: 4),
          Icon(Icons.edit_outlined, color: Colors.white.withOpacity(0.3), size: 11),
        ],
      ]),
    );
  }

  // ── Active session banner ─────────────────────────────────────────────────
  Widget _buildActiveBanner() {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const LockInPage()));
        _loadActiveSession();
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.secondary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
        ),
        child: Row(children: [
          Container(width: 7, height: 7,
              decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Lock-in session active — tap to return',
                style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.secondary, size: 18),
        ]),
      ),
    );
  }

  // ── Section header ────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        Container(
          width: 3, height: 16,
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.2,
          ),
        ),
      ]),
    );
  }

  // ── Daily Challenge Card ──────────────────────────────────────────────────
  Widget _buildDailyChallengeCard() {
    if (_challengeLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const SizedBox(height: 72,
            child: Center(child: CircularProgressIndicator(
                color: AppColors.primaryFixed, strokeWidth: 2.5))),
      );
    }
    if (_challengeError != null || _challenge == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(children: [
          const Expanded(child: Text('Could not load today\'s challenge.',
              style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13))),
          TextButton(onPressed: _loadChallenge,
              child: const Text('Retry',
                  style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold))),
        ]),
      );
    }

    final challenge = _challenge!;
    final areaColor = _weaknessColors[challenge.weaknessArea] ?? AppColors.secondary;
    final areaIcon  = _weaknessIcons[challenge.weaknessArea]  ?? Icons.grid_on_rounded;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.2),
            blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: areaColor.withOpacity(0.18),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: areaColor.withOpacity(0.35)),
            ),
            child: Icon(areaIcon, color: areaColor, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Today's Challenge",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            Text('Resets at midnight',
                style: TextStyle(color: AppColors.onPrimaryContainer, fontSize: 11)),
          ])),
          if (challenge.isCompleted)
            _StatusPill(label: 'Done ✓', color: AppColors.secondaryFixed)
          else if (challenge.isExpired)
            _StatusPill(label: 'Expired', color: AppColors.onPrimaryContainer),
        ]),
        const SizedBox(height: 12),
        Text(challenge.challengeTitle,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 5),
        Text(challenge.challengeDescription,
            style: TextStyle(color: AppColors.onPrimaryContainer, fontSize: 13, height: 1.45),
            maxLines: 3, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(flex: 2, child: _buildChallengeActionButton(challenge, areaColor)),
          if (!challenge.isCompleted && !challenge.isExpired) ...[
            const SizedBox(width: 8),
            Expanded(flex: 1, child: _buildHintButton()),
          ],
        ]),
      ]),
    );
  }

  Widget _buildChallengeActionButton(DailyChallengeModel challenge, Color areaColor) {
    final bool disabled = challenge.isCompleted || challenge.isExpired;
    final String label = disabled
        ? (challenge.isCompleted ? 'Completed' : 'Expired')
        : _challengeActionLabel(challenge);
    return GestureDetector(
      onTap: disabled ? null : () { HapticFeedback.lightImpact(); _onChallengeAction(challenge); },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: disabled ? Colors.white.withOpacity(0.08) : AppColors.secondary,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Center(child: Text(label,
            style: TextStyle(
              color: disabled ? AppColors.onPrimaryContainer : Colors.white,
              fontWeight: FontWeight.bold, fontSize: 13,
            ))),
      ),
    );
  }

  Widget _buildHintButton() {
    return GestureDetector(
      onTap: _showWeaknessHintSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.onPrimaryContainer.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.edit_outlined, color: AppColors.onPrimaryContainer, size: 13),
          const SizedBox(width: 4),
          Text('Weak at…',
              style: TextStyle(color: AppColors.onPrimaryContainer,
                  fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  // ── 2×2 Feature Grid ─────────────────────────────────────────────────────
  Widget _buildFeatureGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: [
        _buildFeatureTile(
          icon: Icons.extension_rounded,
          title: 'Brain Games',
          subtitle: '6 games  •  2–6 min',
          accentColor: AppColors.secondary,
          onTap: () => Navigator.pushNamed(context, '/games'),
        ),
        _buildFeatureTile(
          icon: Icons.menu_book_rounded,
          title: 'Reader',
          subtitle: 'TTS  •  Deep focus',
          accentColor: AppColors.primary,
          onTap: () => Navigator.pushNamed(context, '/books'),
        ),
        _buildFeatureTile(
          icon: Icons.group_outlined,
          title: 'Focus Rooms',
          subtitle: 'Study alongside others',
          accentColor: AppColors.primaryContainer,
          onTap: () => Navigator.pushNamed(context, '/rooms'),
        ),
        _buildWakeUpTile(),
      ],
    );
  }

  Widget _buildFeatureTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accentColor, size: 21),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(
                  color: AppColors.onSurface, fontSize: 13,
                  fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(
                  color: AppColors.onSurfaceVariant, fontSize: 11)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildWakeUpTile() {
    final hasActive = _activeSession != null;
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const LockInPage()));
        _loadActiveSession();
      },
      child: Container(
        decoration: BoxDecoration(
          color: hasActive
              ? AppColors.secondary.withOpacity(0.08)
              : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hasActive
                ? AppColors.secondary.withOpacity(0.4)
                : AppColors.outlineVariant.withOpacity(0.5),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.alarm_rounded, color: AppColors.primary, size: 21),
              ),
              if (hasActive)
                Positioned(
                  top: -2, right: -2,
                  child: Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surfaceContainerLowest, width: 1.5),
                    ),
                  ),
                ),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(hasActive ? 'Active' : 'Wake-Up',
                  style: TextStyle(
                    color: hasActive ? AppColors.secondary : AppColors.onSurface,
                    fontSize: 13, fontWeight: FontWeight.bold,
                  )),
              const SizedBox(height: 2),
              Text(hasActive ? 'Session running' : 'Lock-in mode',
                  style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11)),
            ]),
          ],
        ),
      ),
    );
  }

  // ── AI Coach card ─────────────────────────────────────────────────────────
  Widget _buildCoachingCard() {
    final goalCount = _todayGoals.length;
    final doneCount = _todayGoals.where((g) => g.status == 'DONE').length;
    final progress  = goalCount > 0 ? doneCount / goalCount : 0.0;

    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); Navigator.pushNamed(context, '/coaching'); },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.psychology_outlined, color: AppColors.primary, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('AI Daily Coach',
                  style: TextStyle(color: AppColors.onSurface,
                      fontSize: 14, fontWeight: FontWeight.bold)),
              Text(
                goalCount == 0 ? 'Set your goals for today'
                    : '$doneCount of $goalCount goals done',
                style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
              ),
            ])),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.onSurfaceVariant, size: 20),
          ]),
          if (goalCount > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress, minHeight: 4,
                backgroundColor: AppColors.outlineVariant.withOpacity(0.4),
                valueColor: const AlwaysStoppedAnimation(AppColors.secondary),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  // ── Habits card ───────────────────────────────────────────────────────────
  Widget _buildHabitsCard() {
    return Consumer<HabitProvider>(
      builder: (context, provider, _) {
        final done      = provider.doneCount;
        final total     = provider.totalCount;
        final remaining = total - done;
        return GestureDetector(
          onTap: () { HapticFeedback.lightImpact(); Navigator.pushNamed(context, '/habits'); },
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
                  blurRadius: 8, offset: const Offset(0, 2))],
            ),
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.task_alt_rounded,
                    color: AppColors.secondary, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('My Habits',
                    style: TextStyle(color: AppColors.onSurface,
                        fontSize: 14, fontWeight: FontWeight.bold)),
                Text(
                  provider.isLoading ? 'Loading…'
                      : (remaining == 0 && total > 0)
                          ? 'All done for today 🎉'
                          : '$remaining remaining today',
                  style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
                ),
              ])),
              if (total > 0) ...[
                Row(children: List.generate(total.clamp(0, 5), (i) => Container(
                  margin: const EdgeInsets.only(left: 5),
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < done
                        ? AppColors.secondary
                        : AppColors.outlineVariant,
                  ),
                ))),
                const SizedBox(width: 8),
              ],
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.onSurfaceVariant, size: 20),
            ]),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.label,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.onSurfaceVariant;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(
              color: color, fontSize: 10,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
        ]),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

// ── Deep Focus Ring Painter ───────────────────────────────────────────────────
class _DeepFocusRingPainter extends CustomPainter {
  final double progress;
  _DeepFocusRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - stroke) / 2;

    // Track ring — white translucent on dark hero background
    canvas.drawCircle(
      center, radius,
      Paint()
        ..color = Colors.white.withOpacity(0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    // Progress arc — bright mint green
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = const Color(0xFFA0F4C8)   // AppColors.secondaryFixed
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_DeepFocusRingPainter old) => old.progress != progress;
}
