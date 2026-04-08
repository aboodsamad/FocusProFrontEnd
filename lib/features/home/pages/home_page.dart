import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../providers/user_provider.dart';
import '../../question/pages/question_page.dart';
import '../../games/hub/pages/games_hub_page.dart';
import '../../books/pages/books_page.dart';
import '../../profile/pages/profile_page.dart';
import '../../focus_session/pages/focus_rooms_page.dart';
import '../../habits/providers/habit_provider.dart';
import '../../habits/models/habit.dart';
import '../../habits/pages/manage_habits_page.dart';
import '../../profile/services/activity_log_service.dart';
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
    });
  }

  void _animateScore() {
    // Use the real focus score — no fallback fakes.
    // If the user hasn't done the diagnostic yet, score is 0 and the ring shows empty.
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
    DateTime check = todayDate;
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
  Color _scoreColor(double score) {
    if (score == 0)  return Colors.grey;
    if (score >= 80) return const Color(0xFF10B981);
    if (score >= 65) return AppColors.primaryA;
    if (score >= 50) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }

  String _scoreLabel(double score) {
    if (score == 0)  return 'Not Assessed';
    if (score >= 80) return 'Excellent';
    if (score >= 65) return 'Good';
    if (score >= 50) return 'Fair';
    return 'Needs Work';
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
        backgroundColor: const Color(0xFF0F1624),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log out', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to log out?',
            style: TextStyle(color: Colors.grey[400])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[500])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
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
  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    if (user.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF080D1A),
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryA)),
      );
    }
    // Use the real focus score. 0.0 means the user hasn't taken the diagnostic yet.
    final score = user.focusScore;
    final color = _scoreColor(score);
    return Scaffold(
      backgroundColor: const Color(0xFF080D1A),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildAppBar(user)),
            SliverToBoxAdapter(child: _buildHeroScore(score, color)),
            SliverToBoxAdapter(child: _buildQuickActions()),
            SliverToBoxAdapter(child: _buildStatsRow()),
            SliverToBoxAdapter(child: _buildHabitsSection()),
            SliverToBoxAdapter(child: _buildRecommendationCard()),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
  Widget _buildAppBar(UserProvider user) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ProfilePage())),
          child: Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                  colors: [AppColors.primaryA, AppColors.primaryB]),
              boxShadow: [BoxShadow(
                  color: AppColors.primaryA.withOpacity(0.4), blurRadius: 12)],
            ),
            child: Center(
              child: Text(
                user.displayInitial,
                style: const TextStyle(color: Colors.white,
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_greeting,
              style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          Text(user.name,
              style: const TextStyle(color: Colors.white,
                  fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        const Spacer(),
        _IconBtn(icon: Icons.notifications_outlined, onTap: () {}),
        const SizedBox(width: 8),
        _IconBtn(
          icon: Icons.settings_outlined,
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Settings (TODO)'))),
        ),
        const SizedBox(width: 8),
        _IconBtn(icon: Icons.logout_rounded, onTap: _logout),
      ]),
    );
  }
  Widget _buildHeroScore(double score, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: _HoverContainer(
        borderColor: color,
        glowColor: color,
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_scoreLabel(score),
                    style: TextStyle(color: color, fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              const Text('Your Focus Score',
                  style: TextStyle(color: Colors.white,
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                score == 0
                    ? 'Take the diagnostic to get your score'
                    : 'From your diagnostic + weekly activity',
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
              const SizedBox(height: 18),
              AnimatedBuilder(
                animation: _scoreAnim,
                builder: (_, __) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _scoreAnim.value / 100,
                        minHeight: 8,
                        backgroundColor: Colors.white.withOpacity(0.07),
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('0', style: TextStyle(
                            color: Colors.grey[600], fontSize: 10)),
                        Text('100', style: TextStyle(
                            color: Colors.grey[600], fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(width: 20),
          AnimatedBuilder(
            animation: Listenable.merge([_scoreAnim, _pulseAnim]),
            builder: (_, __) => Transform.scale(
              scale: _pulseAnim.value,
              child: SizedBox(
                width: 96, height: 96,
                child: Stack(alignment: Alignment.center, children: [
                  Container(
                    width: 96, height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 20, spreadRadius: 4)],
                    ),
                  ),
                  CustomPaint(
                    size: const Size(96, 96),
                    painter: _ScoreRingPainter(
                        progress: _scoreAnim.value / 100, color: color),
                  ),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_scoreAnim.value.toStringAsFixed(0),
                        style: const TextStyle(color: Colors.white,
                            fontSize: 28, fontWeight: FontWeight.bold)),
                    Text('pts',
                        style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                  ]),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
  Widget _buildQuickActions() {
    final actions = [
      _ActionItem(icon: Icons.videogame_asset_outlined, label: 'Games',
          sub: '2–6 min', color: const Color(0xFF10B981),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const GamesHubPage()))),
      _ActionItem(icon: Icons.menu_book_outlined, label: 'Reader',
          sub: 'TTS/Text', color: const Color(0xFFF97316),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const BooksPage()))),
      _ActionItem(icon: Icons.headphones_outlined, label: 'Audio',
          sub: 'Focus mode', color: const Color(0xFFEC4899),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const BooksPage(audioMode: true)))),
      _ActionItem(icon: Icons.group_outlined, label: 'Rooms',
          sub: 'Study live', color: const Color(0xFF8B5CF6),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const FocusRoomsPage()))),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionLabel(label: 'Quick Actions'),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: actions.map((a) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SizedBox(width: 90, child: _QuickActionCard(item: a)),
            )).toList(),
          ),
        ),
      ]),
    );
  }
  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionLabel(label: "Today's Stats"),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _StatCard(
              label: 'Distracted', value: '${_distractingMinutes}m',
              icon: Icons.phonelink_off_outlined,
              color: const Color(0xFFEF4444),
              sub: 'scroll time', onTap: _editUsage)),
          const SizedBox(width: 8),
          Expanded(child: _StatCard(
              label: 'Streak',
              value: '$_streakDays ${_streakDays == 1 ? "day" : "days"}',
              icon: Icons.local_fire_department_outlined,
              color: const Color(0xFFF97316),
              sub: _streakDays > 0 ? 'keep going!' : 'start today!')),
          const SizedBox(width: 8),
          Expanded(child: _StatCard(
              label: 'Sessions', value: '$_todaySessions',
              icon: Icons.bar_chart_rounded,
              color: AppColors.primaryA, sub: 'today')),
        ]),
      ]),
    );
  }
  void _editUsage() {
    showDialog<int>(
      context: context,
      builder: (_) {
        final ctl = TextEditingController(text: '$_distractingMinutes');
        return AlertDialog(
          backgroundColor: const Color(0xFF0F1624),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Distracted Minutes',
              style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: ctl, keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Minutes on distracting apps',
              hintStyle: TextStyle(color: Colors.grey[600]),
              filled: true, fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel',
                    style: TextStyle(color: Colors.grey[500]))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryA,
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
        // Persist so the value survives app restarts
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('distracting_minutes', v);
        if (mounted) setState(() => _distractingMinutes = v);
      }
    });
  }
  Widget _buildHabitsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const _SectionLabel(label: "Today's Habits"),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManageHabitsPage()),
            ),
            child: const Text('Manage',
                style: TextStyle(
                    color: AppColors.primaryA,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 10),
        Consumer<HabitProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(
                      color: AppColors.primaryA, strokeWidth: 2),
                ),
              );
            }
            if (provider.habits.isEmpty) {
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ManageHabitsPage()),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1624),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Center(
                    child: Text('Tap to add your first habit',
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 13)),
                  ),
                ),
              );
            }
            final todayIndex = DateTime.now().weekday - 1; // 0=Mon…6=Sun
            final todayHabits = provider.habits
                .where((h) => h.days[todayIndex])
                .toList();

            if (todayHabits.isEmpty) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1624),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.06)),
                ),
                child: Column(children: [
                  Icon(Icons.event_available_outlined,
                      color: Colors.grey[700], size: 28),
                  const SizedBox(height: 8),
                  Text('No habits scheduled for today',
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 13)),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ManageHabitsPage())),
                    child: Text('Manage habits',
                        style: TextStyle(
                            color: AppColors.primaryA,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F1624),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                children: todayHabits.asMap().entries.map((e) {
                  final i = e.key;
                  final habit = todayHabits[i];
                  return _HabitTile(
                    habit: habit,
                    isLast: i == todayHabits.length - 1,
                    onToggle: () => provider.toggle(habit),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ]),
    );
  }
  Widget _buildRecommendationCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: _HoverContainer(
        borderColor: AppColors.primaryA,
        glowColor: AppColors.primaryA,
        useGradientBg: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppColors.primaryA.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.auto_awesome,
                  color: AppColors.primaryA, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('AI Recommendation',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
          const SizedBox(height: 12),
          Text(
            'Do 2 reaction tasks + 10 min reading for 3 days to boost your score by ~5 pts.',
            style: TextStyle(color: Colors.grey[300], fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const QuestionPage())),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppColors.primaryA, AppColors.primaryB]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(child: Text('Quick Test',
                      style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 13))),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Auto-plan (TODO)'))),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: const Center(child: Text('Auto-plan',
                      style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 13))),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
class _HoverContainer extends StatefulWidget {
  final Widget child;
  final Color borderColor;
  final Color glowColor;
  final bool useGradientBg;
  final VoidCallback? onTap;
  const _HoverContainer({
    required this.child,
    required this.borderColor,
    required this.glowColor,
    this.useGradientBg = false,
    this.onTap,
  });
  @override
  State<_HoverContainer> createState() => _HoverContainerState();
}
class _HoverContainerState extends State<_HoverContainer> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: widget.useGradientBg ? null : const Color(0xFF0F1624),
            gradient: widget.useGradientBg
                ? LinearGradient(colors: [
                    AppColors.primaryB.withOpacity(_hovered ? 0.45 : 0.3),
                    AppColors.primaryA.withOpacity(_hovered ? 0.22 : 0.12),
                  ])
                : null,
            border: Border.all(
              color: widget.borderColor.withOpacity(_hovered ? 0.55 : 0.2),
              width: _hovered ? 1.8 : 1.5,
            ),
            boxShadow: [BoxShadow(
              color: widget.glowColor.withOpacity(_hovered ? 0.18 : 0.08),
              blurRadius: _hovered ? 32 : 24,
              spreadRadius: _hovered ? 4 : 2,
            )],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
class _ScoreRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  _ScoreRingPainter({required this.progress, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2 - 6;
    canvas.drawCircle(Offset(cx, cy), r, Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -math.pi / 2, 2 * math.pi * progress, false,
        Paint()
          ..color = color.withOpacity(0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -math.pi / 2, 2 * math.pi * progress, false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round,
      );
    }
  }
  @override
  bool shouldRepaint(_ScoreRingPainter old) =>
      old.progress != progress || old.color != color;
}
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(color: Colors.white,
          fontSize: 16, fontWeight: FontWeight.bold));
}
class _IconBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});
  @override
  State<_IconBtn> createState() => _IconBtnState();
}
class _IconBtnState extends State<_IconBtn> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit:  (_) => setState(() => _hovered = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: _hovered
              ? AppColors.primaryA.withOpacity(0.15)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _hovered
                ? AppColors.primaryA.withOpacity(0.5)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Icon(widget.icon,
            color: _hovered ? AppColors.primaryA : Colors.grey[400], size: 20),
      ),
    ),
  );
}
class _ActionItem {
  final IconData icon;
  final String label, sub;
  final Color color;
  final VoidCallback onTap;
  _ActionItem({required this.icon, required this.label,
    required this.sub, required this.color, required this.onTap});
}
class _QuickActionCard extends StatefulWidget {
  final _ActionItem item;
  const _QuickActionCard({required this.item});
  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}
class _QuickActionCardState extends State<_QuickActionCard> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit:  (_) => setState(() => _hovered = false),
    child: GestureDetector(
      onTap: widget.item.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: widget.item.color.withOpacity(_hovered ? 0.22 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.item.color.withOpacity(_hovered ? 0.55 : 0.18),
            width: _hovered ? 1.8 : 1.0,
          ),
          boxShadow: _hovered
              ? [BoxShadow(color: widget.item.color.withOpacity(0.25),
                  blurRadius: 16, spreadRadius: 1)]
              : [],
        ),
        child: Column(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.item.color.withOpacity(_hovered ? 0.30 : 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(widget.item.icon, color: widget.item.color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(widget.item.label,
              style: const TextStyle(color: Colors.white,
                  fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(widget.item.sub,
              style: TextStyle(color: Colors.grey[600], fontSize: 10)),
        ]),
      ),
    ),
  );
}
class _StatCard extends StatefulWidget {
  final String label, value, sub;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _StatCard({required this.label, required this.value,
    required this.icon, required this.color, required this.sub, this.onTap});
  @override
  State<_StatCard> createState() => _StatCardState();
}
class _StatCardState extends State<_StatCard> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit:  (_) => setState(() => _hovered = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _hovered
              ? widget.color.withOpacity(0.1)
              : const Color(0xFF0F1624),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _hovered
                ? widget.color.withOpacity(0.45)
                : Colors.white.withOpacity(0.06),
            width: _hovered ? 1.5 : 1.0,
          ),
          boxShadow: _hovered
              ? [BoxShadow(color: widget.color.withOpacity(0.2),
                  blurRadius: 14, spreadRadius: 1)]
              : [],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(widget.icon, color: widget.color, size: 18),
          const SizedBox(height: 10),
          Text(widget.value,
              style: TextStyle(color: widget.color,
                  fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(widget.sub,
              style: TextStyle(color: Colors.grey[600], fontSize: 10)),
        ]),
      ),
    ),
  );
}
class _HabitTile extends StatefulWidget {
  final Habit habit;
  final bool isLast;
  final VoidCallback onToggle;
  const _HabitTile(
      {required this.habit, required this.isLast, required this.onToggle});
  @override
  State<_HabitTile> createState() => _HabitTileState();
}

class _HabitTileState extends State<_HabitTile> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final h = widget.habit;
    return Column(children: [
      MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.primaryA.withOpacity(0.06)
                : Colors.transparent,
            borderRadius: widget.isLast
                ? const BorderRadius.vertical(bottom: Radius.circular(16))
                : BorderRadius.zero,
          ),
          child: InkWell(
            onTap: widget.onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: h.doneToday
                        ? const LinearGradient(
                            colors: [AppColors.primaryA, AppColors.primaryB])
                        : null,
                    color: h.doneToday ? null : Colors.transparent,
                    border: h.doneToday
                        ? null
                        : Border.all(
                            color: _hovered
                                ? AppColors.primaryA.withOpacity(0.6)
                                : Colors.grey[600]!,
                            width: 2,
                          ),
                  ),
                  child: h.doneToday
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                        h.title,
                        style: TextStyle(
                          color: h.doneToday
                              ? Colors.grey[600]
                              : (_hovered ? Colors.white : Colors.white70),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          decoration: h.doneToday
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(children: [
                        Icon(Icons.timer_outlined,
                            color: Colors.grey[600], size: 11),
                        const SizedBox(width: 3),
                        Text('${h.durationMinutes} min',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 11)),
                        if (h.streak > 0) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.local_fire_department,
                              color: Colors.orange, size: 11),
                          const SizedBox(width: 2),
                          Text('${h.streak}',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 11)),
                        ],
                      ]),
                    ])),
                Icon(
                  h.icon,
                  color: h.doneToday
                      ? Colors.grey[700]
                      : (_hovered
                          ? AppColors.primaryA.withOpacity(0.7)
                          : Colors.grey[500]),
                  size: 18,
                ),
              ]),
            ),
          ),
        ),
      ),
      if (!widget.isLast)
        Divider(
            height: 1,
            color: Colors.white.withOpacity(0.05),
            indent: 56),
    ]);
  }
}