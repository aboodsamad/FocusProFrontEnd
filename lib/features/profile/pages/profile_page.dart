import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../home/providers/user_provider.dart';
import '../models/activity_log.dart';
import '../services/activity_log_service.dart';
import '../widgets/daily_score_section.dart';
import '../widgets/long_term_score_card.dart';
import '../../lockin/pages/screen_time_stats_page.dart';
import 'settings_page.dart';

// ── Category definition ────────────────────────────────────────────────────────
class _Category {
  final String label;
  final IconData icon;
  final List<String> types; // empty = show all
  const _Category({required this.label, required this.icon, required this.types});
}

const _categories = [
  _Category(label: 'All',      icon: Icons.all_inclusive_rounded,        types: []),
  _Category(label: 'Games',    icon: Icons.sports_esports_rounded,       types: ['GAME_PLAYED', 'DAILY_GAME_PLAYED']),
  _Category(label: 'Reading',  icon: Icons.menu_book_rounded,            types: ['BOOK_SNIPPET_READ', 'AI_COMPREHENSION_PASSED', 'AI_COMPREHENSION_FAILED', 'AI_RETENTION_TEST_SUBMITTED']),
  _Category(label: 'Habits',   icon: Icons.check_circle_outline_rounded, types: ['HABIT_CREATED','HABIT_UPDATED','HABIT_DELETED','HABIT_COMPLETED']),
  _Category(label: 'Rooms',    icon: Icons.groups_rounded,               types: ['FOCUS_ROOM_CREATED','FOCUS_ROOM_JOINED']),
  _Category(label: 'Activity', icon: Icons.timeline_rounded,             types: ['LOGIN','LOGOUT','REGISTER','PROFILE_COMPLETE','PROFILE_UPDATE','LOCK_IN_STARTED','LOCK_IN_ENDED','DAILY_CHALLENGE_COMPLETED','BASELINE_TEST_COMPLETE','DIAGNOSTIC_COMPLETE']),
];

// ── Time filter ────────────────────────────────────────────────────────────────
enum _TimeFilter { today, week, month, all }

extension _TimeFilterExt on _TimeFilter {
  String get label {
    switch (this) {
      case _TimeFilter.today: return 'Today';
      case _TimeFilter.week:  return 'Last 7 Days';
      case _TimeFilter.month: return 'Last 30 Days';
      case _TimeFilter.all:   return 'All Time';
    }
  }

  bool matches(DateTime dt) {
    final now = DateTime.now();
    switch (this) {
      case _TimeFilter.today:
        return dt.year == now.year && dt.month == now.month && dt.day == now.day;
      case _TimeFilter.week:
        return now.difference(dt).inDays < 7;
      case _TimeFilter.month:
        return now.difference(dt).inDays < 30;
      case _TimeFilter.all:
        return true;
    }
  }
}

// ── Page ───────────────────────────────────────────────────────────────────────
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

// ── Page state ────────────────────────────────────────────────────────────────
class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late TabController _tabCtrl;

  List<ActivityLog> _logs = [];
  bool _logsLoading = true;
  _TimeFilter _timeFilter = _TimeFilter.all;

  // ── Real usage stats ───────────────────────────────────────────────────────
  int? _gamesPlayed;
  int? _focusMinutes;
  int? _snippetsExplored;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _tabCtrl = TabController(length: _categories.length, vsync: this)
      ..addListener(() => setState(() {}));

    _loadLogs();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final token = await AuthService.getToken();
    if (token == null) return;
    try {
      final resp = await http.get(
        Uri.parse('${AuthService.baseUrl}/user/stats/today'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200 && mounted) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() {
          _gamesPlayed      = (data['gamesPlayed']      as num?)?.toInt() ?? 0;
          _focusMinutes     = (data['focusMinutes']     as num?)?.toInt() ?? 0;
          _snippetsExplored = (data['snippetsExplored'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadLogs() async {
    final logs = await ActivityLogService.fetchLogs();
    if (!mounted) return;
    setState(() { _logs = logs; _logsLoading = false; });
  }

  @override
  void dispose() {
    _animController.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  List<ActivityLog> get _filtered {
    final cat = _categories[_tabCtrl.index];
    return _logs.where((l) {
      final typeOk = cat.types.isEmpty || cat.types.contains(l.activityType);
      final timeOk = _timeFilter.matches(l.activityDate);
      return typeOk && timeOk;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final score = user.longTermScore > 1.0 ? user.longTermScore : 0.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: const AppBottomNav(current: NavTab.profile),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildAppBar(context)),
                SliverToBoxAdapter(child: _buildProfileHero(user, score)),
                const SliverToBoxAdapter(child: LongTermScoreCard()),
                const SliverToBoxAdapter(child: DailyScoreSection()),
                SliverToBoxAdapter(child: _buildStatCards()),
                SliverToBoxAdapter(child: _buildScreenTimeButton()),
                SliverToBoxAdapter(child: _buildActivityLogSection()),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        ),
      ),
    ));
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────
  Widget _buildAppBar(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          // Brand pill  same design as home page top-right
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
                children: [
                  TextSpan(text: 'Locked', style: TextStyle(color: Colors.white)),
                  TextSpan(text: 'In', style: TextStyle(color: AppColors.secondaryFixed)),
                ],
              ),
            ),
          ),
          const Spacer(),
          // Settings button
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: const Icon(Icons.settings_rounded,
                  color: AppColors.primary, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ── Profile Hero ───────────────────────────────────────────────────────────
  Widget _buildProfileHero(UserProvider user, double score) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
      child: Column(
        children: [
          // Avatar with score badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondaryContainer,
                  border: Border.all(color: AppColors.secondary, width: 3),
                  boxShadow: [BoxShadow(color: AppColors.secondary.withValues(alpha: 0.3), blurRadius: 16, spreadRadius: 2)],
                ),
                child: Center(
                  child: Text(
                    user.displayInitial,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -4, right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.surfaceContainerLowest, width: 2),
                  ),
                  child: Text(
                    score.toInt().toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            user.name,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Long-Term Score: ${score.toInt()} / 100',
            style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14),
          ),
          const SizedBox(height: 12),
          // Chips row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ProfileChip(
                label: 'Flow Master',
                bgColor: AppColors.secondaryContainer,
                textColor: AppColors.secondary,
              ),
              const SizedBox(width: 8),
              _ProfileChip(
                label: 'Top 5% Reader',
                bgColor: AppColors.surfaceContainerLow,
                textColor: AppColors.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Stat Cards ──────────────────────────────────────────────────────────────
  String _formatFocusTime(int? minutes) {
    if (minutes == null) return '…';
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  Widget _buildStatCards() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        children: [
          _StatCard(
            icon: Icons.timer_outlined,
            iconColor: AppColors.secondary,
            value: _formatFocusTime(_focusMinutes),
            label: 'FOCUS TIME',
          ),
          const SizedBox(height: 12),
          _StatCard(
            icon: Icons.extension_outlined,
            iconColor: AppColors.onTertiaryContainer,
            iconBg: AppColors.tertiaryContainer,
            value: _gamesPlayed?.toString() ?? '…',
            label: 'GAMES PLAYED',
          ),
          const SizedBox(height: 12),
          _StatCard(
            icon: Icons.auto_stories_outlined,
            iconColor: AppColors.secondary,
            value: _snippetsExplored?.toString() ?? '…',
            label: 'SNIPPETS EXPLORED',
          ),
        ],
      ),
    );
  }

  // ── Screen Time Button ─────────────────────────────────────────────────────
  Widget _buildScreenTimeButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ScreenTimeStatsPage()),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.phone_android_rounded,
                    color: AppColors.secondary, size: 22),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Screen Time',
                      style: TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Today's app usage breakdown",
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.onSurfaceVariant, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── Activity Log Section ───────────────────────────────────────────────────
  Widget _buildActivityLogSection() {
    final filtered = _filtered;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              const Text(
                'Activity Log',
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {},
                child: const Text(
                  'View History',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Time filter chips
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _TimeFilter.values.map((f) {
                final active = _timeFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _timeFilter = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: active ? AppColors.secondary : AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active ? AppColors.secondary : AppColors.outlineVariant,
                        ),
                      ),
                      child: Text(
                        f.label,
                        style: TextStyle(
                          color: active ? Colors.white : AppColors.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Category tabs
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: TabBar(
              controller: _tabCtrl,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.secondary.withValues(alpha: 0.5)),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: AppColors.secondary,
              unselectedLabelColor: AppColors.onSurfaceVariant,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
              padding: const EdgeInsets.all(4),
              tabs: _categories.map((c) => Tab(
                height: 36,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(c.icon, size: 14),
                    const SizedBox(width: 5),
                    Text(c.label),
                  ],
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Log list
          if (_logsLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(
                  color: AppColors.secondary, strokeWidth: 2.5),
              ),
            )
          else if (filtered.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.outlineVariant),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
              ),
              child: Column(children: [
                Icon(_categories[_tabCtrl.index].icon, color: AppColors.outlineVariant, size: 32),
                const SizedBox(height: 10),
                const Text('Nothing here yet',
                    style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13)),
                const SizedBox(height: 4),
                const Text('Try a different filter or time range',
                    style: TextStyle(color: AppColors.outlineVariant, fontSize: 11)),
              ]),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (_, i) => Padding(
                  padding: EdgeInsets.only(bottom: i == filtered.length - 1 ? 0 : 8),
                  child: _ActivityCard(log: filtered[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }

}

// ── Profile Chip ───────────────────────────────────────────────────────────────
class _ProfileChip extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color textColor;
  const _ProfileChip({required this.label, required this.bgColor, required this.textColor});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
}

// ── Stat Card ──────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color? iconBg;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    this.iconBg,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: iconBg ?? AppColors.secondary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ── Activity Card ──────────────────────────────────────────────────────────────
class _ActivityCard extends StatelessWidget {
  final ActivityLog log;
  const _ActivityCard({required this.log});

  static const _typeConfig = {
    'LOGIN':                       _ActivityMeta(icon: Icons.login_rounded,                  color: Color(0xFF10B981), label: 'Login'),
    'LOGOUT':                      _ActivityMeta(icon: Icons.logout_rounded,                 color: Color(0xFF6B7A99), label: 'Logout'),
    'REGISTER':                    _ActivityMeta(icon: Icons.person_add_alt_1_rounded,       color: AppColors.secondary, label: 'Registered'),
    'PROFILE_COMPLETE':            _ActivityMeta(icon: Icons.manage_accounts_rounded,        color: Color(0xFF818CF8), label: 'Profile'),
    'PROFILE_UPDATE':              _ActivityMeta(icon: Icons.edit_rounded,                   color: Color(0xFF818CF8), label: 'Profile Updated'),
    'DIAGNOSTIC_COMPLETE':         _ActivityMeta(icon: Icons.psychology_rounded,             color: Color(0xFFF97316), label: 'Diagnostic'),
    'BASELINE_TEST_COMPLETE':      _ActivityMeta(icon: Icons.bar_chart_rounded,              color: Color(0xFFEC4899), label: 'Baseline Test'),
    'GAME_PLAYED':                 _ActivityMeta(icon: Icons.sports_esports_rounded,         color: AppColors.onTertiaryContainer, label: 'Game'),
    'DAILY_GAME_PLAYED':           _ActivityMeta(icon: Icons.stars_rounded,                  color: Color(0xFFFFD166), label: 'Daily Game'),
    'BOOK_SNIPPET_READ':           _ActivityMeta(icon: Icons.menu_book_rounded,              color: AppColors.secondary, label: 'Snippet Read'),
    'AI_COMPREHENSION_PASSED':     _ActivityMeta(icon: Icons.check_circle_rounded,           color: Color(0xFF10B981), label: 'Quiz Passed'),
    'AI_COMPREHENSION_FAILED':     _ActivityMeta(icon: Icons.cancel_rounded,                 color: Color(0xFFFF5270), label: 'Quiz Failed'),
    'AI_RETENTION_TEST_SUBMITTED': _ActivityMeta(icon: Icons.auto_awesome_rounded,           color: Color(0xFF818CF8), label: 'Retention Test'),
    'HABIT_CREATED':               _ActivityMeta(icon: Icons.add_task_rounded,               color: Color(0xFFA78BFA), label: 'Habit Created'),
    'HABIT_UPDATED':               _ActivityMeta(icon: Icons.edit_note_rounded,              color: Color(0xFF818CF8), label: 'Habit Updated'),
    'HABIT_DELETED':               _ActivityMeta(icon: Icons.delete_outline_rounded,         color: Color(0xFFFF5270), label: 'Habit Deleted'),
    'HABIT_COMPLETED':             _ActivityMeta(icon: Icons.check_circle_outline_rounded,   color: Color(0xFF10B981), label: 'Habit Done'),
    'FOCUS_ROOM_CREATED':          _ActivityMeta(icon: Icons.meeting_room_rounded,           color: Color(0xFFFFD166), label: 'Room Created'),
    'FOCUS_ROOM_JOINED':           _ActivityMeta(icon: Icons.groups_rounded,                 color: Color(0xFFFB923C), label: 'Room Joined'),
    'LOCK_IN_STARTED':             _ActivityMeta(icon: Icons.lock_clock_rounded,             color: Color(0xFF06B6D4), label: 'Lock-In Started'),
    'LOCK_IN_ENDED':               _ActivityMeta(icon: Icons.lock_open_rounded,              color: Color(0xFF64748B), label: 'Lock-In Ended'),
    'DAILY_CHALLENGE_COMPLETED':   _ActivityMeta(icon: Icons.emoji_events_rounded,           color: Color(0xFFFFD166), label: 'Challenge Done'),
    'DAILY_CHALLENGE_GENERATED':   _ActivityMeta(icon: Icons.flag_rounded,                   color: Color(0xFF94A3B8), label: 'Challenge Set'),
  };

  static _ActivityMeta _meta(String type) =>
      _typeConfig[type] ??
      const _ActivityMeta(icon: Icons.circle_outlined, color: AppColors.secondary, label: 'Activity');

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final meta = _meta(log.activityType);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: meta.color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(meta.icon, color: meta.color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              log.activityDescription ?? meta.label,
              style: const TextStyle(
                color: AppColors.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              meta.label,
              style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        Text(
          _timeAgo(log.activityDate),
          style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11),
        ),
      ]),
    );
  }
}

class _ActivityMeta {
  final IconData icon;
  final Color color;
  final String label;
  const _ActivityMeta({required this.icon, required this.color, required this.label});
}
