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
import '../../games/daily/models/daily_game_models.dart';
import '../../games/daily/services/daily_game_service.dart';
import '../../games/daily/pages/daily_game_page.dart';

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

  // ── Daily game state ──────────────────────────────────────────────────────
  DailyGameStatus? _dailyGameStatus;

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
    try {
      _dailyGameStatus = await DailyGameService.getTodayStatus();
    } catch (_) {}
    if (mounted) setState(() {});

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

    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: _buildBottomNav(),
      body: Column(
        children: [
          // ── Non-scrollable header + score block ──────────────────────────
          SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(user),
                _buildScoreBlock(),
              ],
            ),
          ),
          // ── Scrollable content ───────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_activeSession != null) _buildActiveBanner(),

                  const SizedBox(height: 16),
                  _buildSectionHeader("Today's Challenge"),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildDailyChallengeCard(),
                  ),

                  const SizedBox(height: 16),
                  _buildSectionHeader('Features'),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildFeaturesBento(),
                  ),

                  _buildDailyGameBanner(),

                  const SizedBox(height: 16),
                  _buildSectionHeader('Your Progress'),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(children: [
                      _buildCoachingCard(),
                      const SizedBox(height: 8),
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

  // ── Light header row ──────────────────────────────────────────────────────
  Widget _buildHeader(UserProvider user) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Row(children: [
        // Greeting
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$_greeting,',
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w500,
                    color: AppColors.outline, letterSpacing: 0.2)),
            Text(user.name ?? 'Focus Pro',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700,
                    color: AppColors.primary, height: 1.2)),
          ]),
        ),
        // FocusPro brand pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
          child: RichText(text: const TextSpan(
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                letterSpacing: -0.3),
            children: [
              TextSpan(text: 'Focus', style: TextStyle(color: Colors.white)),
              TextSpan(text: 'Pro',
                  style: TextStyle(color: AppColors.secondaryFixed)),
            ],
          )),
        ),
        const SizedBox(width: 8),
        // Logout
        GestureDetector(
          onTap: _logout,
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceContainerLowest,
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: const Icon(Icons.logout_rounded,
                color: AppColors.onSurfaceVariant, size: 17),
          ),
        ),
      ]),
    );
  }

  // ── Score block card ──────────────────────────────────────────────────────
  Widget _buildScoreBlock() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: AnimatedBuilder(
        animation: _scoreAnim,
        builder: (_, __) {
          final s = _scoreAnim.value;
          final mood = s >= 70 ? 'Great focus today'
              : s >= 40 ? 'Building momentum'
              : "Let's get started";
          return Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Decorative circles
                Positioned(
                  right: -30, top: -30,
                  child: Container(
                    width: 160, height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.secondaryFixed.withOpacity(0.12)),
                    ),
                  ),
                ),
                Positioned(
                  right: 10, top: 10,
                  child: Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.secondaryFixed.withOpacity(0.08)),
                    ),
                  ),
                ),
                // Content row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left: score + bar + mood
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('FOCUS SCORE',
                              style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w700,
                                  color: Colors.white.withOpacity(0.45),
                                  letterSpacing: 2)),
                          const SizedBox(height: 2),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(s.toStringAsFixed(0),
                                  style: const TextStyle(
                                      fontSize: 72, fontWeight: FontWeight.w900,
                                      color: Colors.white, letterSpacing: -3,
                                      height: 0.9)),
                              const SizedBox(width: 6),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text('/100',
                                    style: TextStyle(
                                        fontSize: 20, fontWeight: FontWeight.w300,
                                        color: Colors.white.withOpacity(0.3))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Progress bar
                          LayoutBuilder(builder: (ctx, box) {
                            final w = box.maxWidth * 0.82;
                            return SizedBox(
                              width: w, height: 3,
                              child: Stack(children: [
                                Container(
                                    width: w, height: 3,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    )),
                                AnimatedContainer(
                                    duration: const Duration(milliseconds: 1100),
                                    curve: Curves.easeOutCubic,
                                    width: w * (s / 100).clamp(0, 1),
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: AppColors.secondaryFixed,
                                      borderRadius: BorderRadius.circular(4),
                                    )),
                              ]),
                            );
                          }),
                          const SizedBox(height: 6),
                          Text(mood,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.5))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Right: 3 stats stacked
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _ScoreStat(emoji: '🔥',
                            value: '$_streakDays', label: 'streak'),
                        const SizedBox(height: 14),
                        _ScoreStat(emoji: '⚡',
                            value: '$_todaySessions', label: 'sessions'),
                        const SizedBox(height: 14),
                        GestureDetector(
                          onTap: _editUsage,
                          child: _ScoreStat(emoji: '🚫',
                              value: '${_distractingMinutes}m', label: 'dist.'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
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
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.secondary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.secondary.withOpacity(0.25)),
        ),
        child: Row(children: [
          Container(width: 7, height: 7,
              decoration: const BoxDecoration(
                  color: AppColors.secondary, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Lock-in session active — tap to return',
                style: TextStyle(color: AppColors.secondary,
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.secondary, size: 18),
        ]),
      ),
    );
  }

  // ── Section header ────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: AppColors.outline, letterSpacing: 1.0,
        ),
      ),
    );
  }

  // ── Daily Challenge Card ──────────────────────────────────────────────────
  Widget _buildDailyChallengeCard() {
    if (_challengeLoading) {
      return Container(
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: const Center(child: CircularProgressIndicator(
            color: AppColors.primary, strokeWidth: 2.5)),
      );
    }
    if (_challengeError != null || _challenge == null) {
      return Container(
        padding: const EdgeInsets.all(16),
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
                  style: TextStyle(color: AppColors.secondary,
                      fontWeight: FontWeight.bold))),
        ]),
      );
    }

    final challenge = _challenge!;
    final areaColor = _weaknessColors[challenge.weaknessArea] ?? AppColors.secondary;
    final areaIcon  = _weaknessIcons[challenge.weaknessArea]  ?? Icons.grid_on_rounded;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Colored top strip
        Container(
          color: areaColor,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(children: [
            Icon(areaIcon, color: Colors.white, size: 15),
            const SizedBox(width: 8),
            const Text("TODAY'S CHALLENGE",
                style: TextStyle(color: Colors.white, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            const Spacer(),
            if (challenge.isCompleted)
              _StatusPill(label: 'Done ✓', color: Colors.white)
            else if (challenge.isExpired)
              _StatusPill(label: 'Expired', color: Colors.white70)
            else
              Text('Resets at midnight',
                  style: TextStyle(
                      fontSize: 10, color: Colors.white.withOpacity(0.65))),
          ]),
        ),
        // Body
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(challenge.challengeTitle,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
            const SizedBox(height: 4),
            Text(challenge.challengeDescription,
                style: const TextStyle(fontSize: 12, color: AppColors.outline,
                    height: 1.45),
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
        ),
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
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: disabled ? AppColors.surfaceContainerLow : AppColors.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(child: Text(label,
            style: TextStyle(
              color: disabled ? AppColors.outline : Colors.white,
              fontWeight: FontWeight.bold, fontSize: 13,
            ))),
      ),
    );
  }

  Widget _buildHintButton() {
    return GestureDetector(
      onTap: _showWeaknessHintSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.outlineVariant),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.edit_outlined, color: AppColors.outline, size: 13),
          const SizedBox(width: 4),
          const Text('Weak at…',
              style: TextStyle(color: AppColors.outline,
                  fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  // ── Features Bento ────────────────────────────────────────────────────────
  Widget _buildFeaturesBento() {
    return Column(children: [
      // Brain Games — full width
      GestureDetector(
        onTap: () { HapticFeedback.lightImpact(); Navigator.pushNamed(context, '/games'); },
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.outlineVariant),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
                blurRadius: 6, offset: const Offset(0, 2))],
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Brain Games',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
                const SizedBox(height: 2),
                const Text('7 games  ·  2–6 min each',
                    style: TextStyle(fontSize: 11, color: AppColors.outline)),
                const SizedBox(height: 10),
                // Category chips
                Wrap(spacing: 6, children: ['Memory', 'Speed', 'Logic', 'Focus']
                    .map((g) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(g, style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant)),
                )).toList()),
              ]),
              // Category dots
              Column(children: [
                AppColors.secondary, AppColors.secondaryFixed,
                AppColors.primaryFixed, AppColors.onPrimaryContainer,
              ].map((c) => Container(
                margin: const EdgeInsets.only(bottom: 5),
                width: 8, height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: c),
              )).toList()),
            ],
          ),
        ),
      ),

      const SizedBox(height: 8),

      // Reader + Focus Rooms — half/half
      Row(children: [
        Expanded(child: _buildSmallBentoCard(
          icon: Icons.menu_book_rounded,
          title: 'Reader',
          subtitle: 'TTS · Deep focus',
          accentColor: AppColors.primary,
          onTap: () => Navigator.pushNamed(context, '/books'),
        )),
        const SizedBox(width: 8),
        Expanded(child: _buildSmallBentoCard(
          icon: Icons.group_outlined,
          title: 'Focus Rooms',
          subtitle: 'Study with others',
          accentColor: AppColors.secondary,
          onTap: () => Navigator.pushNamed(context, '/rooms'),
        )),
      ]),

      const SizedBox(height: 8),

      // Wake-Up / Lock-In — full width dark green
      GestureDetector(
        onTap: () async {
          HapticFeedback.lightImpact();
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const LockInPage()));
          _loadActiveSession();
        },
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _activeSession != null ? 'Session Active' : 'Wake-Up · Lock-In',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  _activeSession != null
                      ? 'Tap to return to your session'
                      : 'Start a distraction-free session',
                  style: const TextStyle(fontSize: 11,
                      color: AppColors.onPrimaryContainer),
                ),
              ]),
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _activeSession != null ? Icons.arrow_forward_rounded : Icons.alarm_rounded,
                  color: AppColors.secondaryFixed, size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _buildSmallBentoCard({
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
          border: Border.all(color: AppColors.outlineVariant),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
              blurRadius: 6, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
              color: AppColors.primary)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 10,
              color: AppColors.outline)),
        ]),
      ),
    );
  }

  // ── Daily Game Banner ─────────────────────────────────────────────────────
  Widget _buildDailyGameBanner() {
    final dayIndex = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000 % 3;
    Color bannerColor;
    IconData bannerIcon;
    String bannerSubtitle;
    switch (dayIndex) {
      case 0:
        bannerColor    = AppColors.secondary;
        bannerIcon     = Icons.grid_view_rounded;
        bannerSubtitle = 'Visual N-Back · Memory';
        break;
      case 1:
        bannerColor    = AppColors.primary;
        bannerIcon     = Icons.radio_button_checked_rounded;
        bannerSubtitle = 'Go/No-Go · Inhibition';
        break;
      default:
        bannerColor    = AppColors.primaryContainer;
        bannerIcon     = Icons.compare_arrows_rounded;
        bannerSubtitle = 'Flanker Task · Attention';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DailyGamePage()),
        ).then((_) => _loadStats()),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outlineVariant),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
                blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: bannerColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(bannerIcon, color: bannerColor, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Daily Game', style: TextStyle(
                    color: AppColors.onSurface, fontSize: 14,
                    fontWeight: FontWeight.bold)),
                Text(bannerSubtitle, style: const TextStyle(
                    color: AppColors.onSurfaceVariant, fontSize: 11)),
              ],
            )),
            if (_dailyGameStatus?.hasPlayed == true)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Played ✓', style: TextStyle(
                    color: AppColors.secondary, fontSize: 12,
                    fontWeight: FontWeight.w600)))
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                child: const Text('Play', style: TextStyle(
                    color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.bold))),
          ]),
        ),
      ),
    );
  }

  // ── AI Coach card ─────────────────────────────────────────────────────────
  Widget _buildCoachingCard() {
    final goalCount = _todayGoals.length;
    final doneCount = _todayGoals.where((g) => g.status == 'DONE').length;
    final progress  = goalCount > 0 ? doneCount / goalCount : 0.0;
    final pct       = goalCount > 0 ? '${(progress * 100).round()}%' : '';

    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); Navigator.pushNamed(context, '/coaching'); },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.outlineVariant),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.psychology_outlined,
                  color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Text('AI Daily Coach', style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: AppColors.onSurface)),
              Text(goalCount == 0 ? 'Set your goals for today'
                  : '$doneCount of $goalCount goals done',
                  style: const TextStyle(fontSize: 11, color: AppColors.outline)),
            ])),
            if (pct.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.secondaryFixed,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(pct, style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: AppColors.onSecondaryContainer)),
              ),
          ]),
          if (goalCount > 0) ...[
            const SizedBox(height: 10),
            // Thin progress track
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                widthFactor: progress.clamp(0, 1),
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Goals list — up to 4 items
            ...(_todayGoals.take(4).map((g) {
              final isDone = g.status == 'DONE';
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Container(
                    width: 16, height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone ? AppColors.secondary : Colors.transparent,
                      border: Border.all(
                          color: isDone ? AppColors.secondary : AppColors.outlineVariant,
                          width: 1.5),
                    ),
                    child: isDone
                        ? const Icon(Icons.check, color: Colors.white, size: 10)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(g.goalText,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDone ? AppColors.outline : AppColors.onSurface,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                        )),
                  ),
                ]),
              );
            })),
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
        // Day-of-week squares: fill first `done` squares
        final dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
        final today = DateTime.now().weekday - 1; // 0=Mon

        return GestureDetector(
          onTap: () { HapticFeedback.lightImpact(); Navigator.pushNamed(context, '/habits'); },
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.outlineVariant),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
                  blurRadius: 8, offset: const Offset(0, 2))],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.task_alt_rounded,
                      color: AppColors.secondary, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Daily Habits', style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: AppColors.onSurface)),
                  Text(
                    provider.isLoading ? 'Loading…'
                        : (remaining == 0 && total > 0) ? 'All done today!'
                        : '$remaining remaining today',
                    style: const TextStyle(fontSize: 11, color: AppColors.outline),
                  ),
                ])),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.outlineVariant, size: 18),
              ]),
              if (total > 0) ...[
                const SizedBox(height: 12),
                Row(
                  children: List.generate(7, (i) {
                    final filled = i <= today && (today - i) < _streakDays;
                    final isToday = i == today;
                    return Expanded(child: Column(children: [
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 28,
                        decoration: BoxDecoration(
                          color: filled
                              ? AppColors.secondaryFixed
                              : AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(6),
                          border: isToday
                              ? Border.all(color: AppColors.secondary, width: 1.5)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(dayLabels[i], style: const TextStyle(
                          fontSize: 9, color: AppColors.outline)),
                    ]));
                  }),
                ),
              ],
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

class _HeroStat extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final VoidCallback? onTap;
  const _HeroStat({required this.icon, required this.iconColor,
      required this.value, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(color: Colors.white,
                  fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 1),
          Text(label,
              style: TextStyle(color: Colors.white.withOpacity(0.5),
                  fontSize: 9, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 30, color: Colors.white.withOpacity(0.12));
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.label,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon,
                color: selected ? Colors.white : AppColors.onSurfaceVariant,
                size: 22),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(
              color: selected ? AppColors.primary : AppColors.onSurfaceVariant,
              fontSize: 10,
              fontWeight: selected ? FontWeight.w700 : FontWeight.normal)),
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

// ── Score Stat (used inside score block) ─────────────────────────────────────
class _ScoreStat extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  const _ScoreStat({required this.emoji,
      required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(value, style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700,
            color: Colors.white, height: 1)),
        Text(label, style: TextStyle(
            fontSize: 9, color: Colors.white.withOpacity(0.4),
            fontWeight: FontWeight.w500)),
      ]),
      const SizedBox(width: 6),
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(emoji, style: const TextStyle(fontSize: 14)),
        ),
      ),
    ]);
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
