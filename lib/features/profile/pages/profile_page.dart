import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../home/providers/user_provider.dart';
import '../models/activity_log.dart';
import '../services/activity_log_service.dart';

// ── Category definition ────────────────────────────────────────────────────────
class _Category {
  final String label;
  final IconData icon;
  final List<String> types; // empty = show all
  const _Category({required this.label, required this.icon, required this.types});
}

const _categories = [
  _Category(label: 'All',     icon: Icons.all_inclusive_rounded,       types: []),
  _Category(label: 'Games',   icon: Icons.sports_esports_rounded,      types: ['GAME_PLAYED']),
  _Category(label: 'Reading', icon: Icons.menu_book_rounded,           types: ['BOOK_SNIPPET_READ']),
  _Category(label: 'Habits',  icon: Icons.check_circle_outline_rounded,types: ['HABIT_CREATED','HABIT_UPDATED','HABIT_DELETED','HABIT_COMPLETED']),
  _Category(label: 'Rooms',   icon: Icons.groups_rounded,              types: ['FOCUS_ROOM_CREATED','FOCUS_ROOM_JOINED']),
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
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

// ── Snippet history model ──────────────────────────────────────────────────────
class _SnippetHistoryItem {
  final int     snippetId;
  final String  snippetTitle;
  final int     bookId;
  final String  bookTitle;
  final int     questionCount;
  final String? attemptResult;  // "PASSED", "FAILED", or null
  final int?    correctCount;   // how many correct, null if never submitted
  final int?    totalCount;     // total questions attempted, null if never submitted
  final DateTime? createdAt;

  const _SnippetHistoryItem({
    required this.snippetId,
    required this.snippetTitle,
    required this.bookId,
    required this.bookTitle,
    required this.questionCount,
    this.attemptResult,
    this.correctCount,
    this.totalCount,
    this.createdAt,
  });

  factory _SnippetHistoryItem.fromJson(Map<String, dynamic> j) {
    DateTime? dt;
    try { dt = DateTime.parse(j['createdAt'] as String); } catch (_) {}
    return _SnippetHistoryItem(
      snippetId:     (j['snippetId']     as num).toInt(),
      snippetTitle:  j['snippetTitle']   as String,
      bookId:        (j['bookId']        as num).toInt(),
      bookTitle:     j['bookTitle']      as String,
      questionCount: (j['questionCount'] as num).toInt(),
      attemptResult: j['attemptResult']  as String?,
      correctCount:  j['correctCount']  != null ? (j['correctCount'] as num).toInt() : null,
      totalCount:    j['totalCount']    != null ? (j['totalCount']   as num).toInt() : null,
      createdAt:     dt,
    );
  }
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

  // ── AI history state ───────────────────────────────────────────────────────
  List<_SnippetHistoryItem> _aiHistory = [];
  bool   _aiHistoryLoading = true;
  bool   _aiHistoryToday   = false;   // false = all-time
  String? _aiBookFilter;              // null = all books

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
    _loadAiHistory();
  }

  Future<void> _loadLogs() async {
    final logs = await ActivityLogService.fetchLogs();
    if (mounted) setState(() { _logs = logs; _logsLoading = false; });
  }

  Future<void> _loadAiHistory() async {
    final token = await AuthService.getToken();
    if (token == null) {
      if (mounted) setState(() => _aiHistoryLoading = false);
      return;
    }
    try {
      final resp = await http.get(
        Uri.parse('${AuthService.baseUrl}/ai/history'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200 && mounted) {
        final List<dynamic> data = jsonDecode(resp.body) as List<dynamic>;
        setState(() {
          _aiHistory = data
              .map((e) => _SnippetHistoryItem.fromJson(e as Map<String, dynamic>))
              .toList();
          _aiHistoryLoading = false;
        });
      } else {
        if (mounted) setState(() => _aiHistoryLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _aiHistoryLoading = false);
    }
  }

  List<_SnippetHistoryItem> get _filteredAiHistory {
    final now = DateTime.now();
    return _aiHistory.where((item) {
      if (_aiHistoryToday) {
        final dt = item.createdAt;
        if (dt == null) return false;
        if (dt.year != now.year || dt.month != now.month || dt.day != now.day) return false;
      }
      if (_aiBookFilter != null && item.bookTitle != _aiBookFilter) return false;
      return true;
    }).toList();
  }

  List<String> get _aiBookTitles =>
      _aiHistory.map((e) => e.bookTitle).toSet().toList()..sort();

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

  Color _scoreColor(double score) {
    if (score >= 80) return const Color(0xFF10B981);
    if (score >= 65) return AppColors.primaryA;
    if (score >= 50) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }

  String _scoreLabel(double score) {
    if (score >= 80) return 'Excellent';
    if (score >= 65) return 'Good';
    if (score >= 50) return 'Fair';
    return 'Needs Work';
  }

  String _formatDob(String dob) {
    if (dob.isEmpty) return 'Not set';
    try {
      final dt = DateTime.parse(dob);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) { return dob; }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final score = user.focusScore > 1.0 ? user.focusScore : 0.0;
    final scoreColor = _scoreColor(score);

    return Scaffold(
      backgroundColor: const Color(0xFF080D1A),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(context)),
                SliverToBoxAdapter(child: _buildAvatar(user, scoreColor, score)),
                SliverToBoxAdapter(child: _buildInfoSection(user)),
                SliverToBoxAdapter(child: _buildScoreSection(score, scoreColor)),
                SliverToBoxAdapter(child: _buildJourneySection()),
                SliverToBoxAdapter(child: _buildAiHistorySection()),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          _IconBtn(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          const Text('Profile',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ── Avatar ──────────────────────────────────────────────────────────────────

  Widget _buildAvatar(UserProvider user, Color scoreColor, double score) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
      child: Column(
        children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.primaryA, AppColors.primaryB],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              boxShadow: [BoxShadow(color: AppColors.primaryA.withOpacity(0.45), blurRadius: 24, spreadRadius: 4)],
            ),
            child: Center(
              child: Text(user.displayInitial,
                  style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
          Text(user.name,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          if (user.username.isNotEmpty)
            Text('@${user.username}', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          const SizedBox(height: 10),
          if (user.roleName.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryA.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primaryA.withOpacity(0.3)),
              ),
              child: Text(user.roleName,
                  style: const TextStyle(color: AppColors.primaryA, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  // ── Info Section ────────────────────────────────────────────────────────────

  Widget _buildInfoSection(UserProvider user) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel(label: 'Account Info'),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F1624),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(children: [
              _InfoTile(icon: Icons.email_outlined,   label: 'Email',       value: user.email.isNotEmpty    ? user.email    : 'Not set',      iconColor: AppColors.primaryA,        isLast: false),
              _InfoTile(icon: Icons.cake_outlined,    label: 'Date of Birth',value: _formatDob(user.dob),                                    iconColor: const Color(0xFFF97316),   isLast: false),
              _InfoTile(icon: Icons.badge_outlined,   label: 'Username',    value: user.username.isNotEmpty ? user.username : 'Not set',      iconColor: const Color(0xFF10B981),   isLast: false),
              _InfoTile(icon: Icons.tag_rounded,      label: 'User ID',     value: user.userId != null      ? '#${user.userId}' : 'Unknown',  iconColor: const Color(0xFFEC4899),   isLast: true),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Score Section ───────────────────────────────────────────────────────────

  Widget _buildScoreSection(double score, Color scoreColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel(label: 'Focus Score'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1624),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scoreColor.withOpacity(0.25)),
              boxShadow: [BoxShadow(color: scoreColor.withOpacity(0.1), blurRadius: 20, spreadRadius: 2)],
            ),
            child: Row(children: [
              SizedBox(
                width: 80, height: 80,
                child: CustomPaint(
                  painter: _ScoreRingPainter(progress: score / 100, color: scoreColor),
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(score.toStringAsFixed(0),
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      Text('pts', style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: scoreColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(score > 0 ? _scoreLabel(score) : 'Not assessed',
                        style: TextStyle(color: scoreColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    score > 0
                        ? 'Based on your diagnostic and activity'
                        : 'Complete the diagnostic to get your score',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12, height: 1.4),
                  ),
                  if (score > 0) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: score / 100,
                        minHeight: 6,
                        backgroundColor: Colors.white.withOpacity(0.07),
                        valueColor: AlwaysStoppedAnimation(scoreColor),
                      ),
                    ),
                  ],
                ]),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ── AI Question History Section ─────────────────────────────────────────────

  Widget _buildAiHistorySection() {
    final items   = _filteredAiHistory;
    final books   = _aiBookTitles;
    const accent  = Color(0xFF818CF8); // indigo accent for AI sections

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: accent, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'AI Question History',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (!_aiHistoryLoading)
                Text(
                  '${items.length} snippet${items.length == 1 ? '' : 's'}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Time filter chips ───────────────────────────────────────────────
          Row(
            children: [
              _FilterChip(
                label: 'All Time',
                active: !_aiHistoryToday,
                activeColor: accent,
                onTap: () => setState(() { _aiHistoryToday = false; }),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Today',
                active: _aiHistoryToday,
                activeColor: accent,
                onTap: () => setState(() { _aiHistoryToday = true; }),
              ),
              const Spacer(),
              // Book filter dropdown
              if (books.isNotEmpty)
                _BookFilterDropdown(
                  books: books,
                  selected: _aiBookFilter,
                  onChanged: (v) => setState(() => _aiBookFilter = v),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Content ─────────────────────────────────────────────────────────
          if (_aiHistoryLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(
                  color: accent, strokeWidth: 2.5),
              ),
            )
          else if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1624),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(children: [
                Icon(Icons.auto_awesome_outlined, color: Colors.grey[700], size: 32),
                const SizedBox(height: 10),
                Text(
                  _aiHistoryToday ? 'No AI questions today' : 'No AI questions yet',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'Read a book snippet to get AI questions',
                  style: TextStyle(color: Colors.grey[700], fontSize: 11),
                ),
              ]),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (_, i) => Padding(
                  padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 10),
                  child: _SnippetHistoryCard(item: items[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Journey Section ─────────────────────────────────────────────────────────

  Widget _buildJourneySection() {
    final filtered = _filtered;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              const Text('My Journey',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (!_logsLoading)
                Text('${filtered.length} entries',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
          const SizedBox(height: 14),

          // Time filter chips
          SizedBox(
            height: 32,
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: active ? AppColors.primaryA : const Color(0xFF0F1624),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active ? AppColors.primaryA : Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Text(
                        f.label,
                        style: TextStyle(
                          color: active ? Colors.white : Colors.grey[500],
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
              color: const Color(0xFF0A0F1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: TabBar(
              controller: _tabCtrl,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: AppColors.primaryA.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primaryA.withOpacity(0.4)),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: AppColors.primaryA,
              unselectedLabelColor: Colors.grey[600],
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
          const SizedBox(height: 10),

          // Log list
          if (_logsLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(color: AppColors.primaryA),
              ),
            )
          else if (filtered.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1624),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(children: [
                Icon(_categories[_tabCtrl.index].icon, color: Colors.grey[700], size: 32),
                const SizedBox(height: 10),
                Text('Nothing here yet',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                const SizedBox(height: 4),
                Text('Try a different filter or time range',
                    style: TextStyle(color: Colors.grey[700], fontSize: 11)),
              ]),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F1624),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              constraints: const BoxConstraints(maxHeight: 360),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, i) => Divider(
                    height: 1,
                    color: Colors.white.withOpacity(0.05),
                    indent: 66,
                  ),
                  itemBuilder: (_, i) => _ActivityTile(
                    log: filtered[i],
                    isLast: i == filtered.length - 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Info Tile ──────────────────────────────────────────────────────────────────
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final bool isLast;

  const _InfoTile({
    required this.icon, required this.label, required this.value,
    required this.iconColor, required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
              ]),
            ),
          ]),
        ),
        if (!isLast) Divider(height: 1, color: Colors.white.withOpacity(0.05), indent: 66),
      ],
    );
  }
}

// ── Section Label ──────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
      );
}

// ── Icon Button ────────────────────────────────────────────────────────────────
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
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _hovered ? AppColors.primaryA.withOpacity(0.15) : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _hovered ? AppColors.primaryA.withOpacity(0.5) : Colors.white.withOpacity(0.08),
              ),
            ),
            child: Icon(widget.icon,
                color: _hovered ? AppColors.primaryA : Colors.grey[400], size: 18),
          ),
        ),
      );
}

// ── Activity Tile ──────────────────────────────────────────────────────────────
class _ActivityTile extends StatelessWidget {
  final ActivityLog log;
  final bool isLast;
  const _ActivityTile({required this.log, required this.isLast});

  static const _typeConfig = {
    'LOGIN':                  _ActivityMeta(icon: Icons.login_rounded,                 color: Color(0xFF10B981), label: 'Login'),
    'LOGOUT':                 _ActivityMeta(icon: Icons.logout_rounded,                color: Color(0xFF6B7A99), label: 'Logout'),
    'REGISTER':               _ActivityMeta(icon: Icons.person_add_alt_1_rounded,      color: AppColors.primaryA, label: 'Registered'),
    'PROFILE_COMPLETE':       _ActivityMeta(icon: Icons.manage_accounts_rounded,       color: Color(0xFF818CF8), label: 'Profile'),
    'DIAGNOSTIC_COMPLETE':    _ActivityMeta(icon: Icons.psychology_rounded,            color: Color(0xFFF97316), label: 'Diagnostic'),
    'BASELINE_TEST_COMPLETE': _ActivityMeta(icon: Icons.bar_chart_rounded,             color: Color(0xFFEC4899), label: 'Baseline Test'),
    'GAME_PLAYED':            _ActivityMeta(icon: Icons.sports_esports_rounded,        color: Color(0xFF5B8FFF), label: 'Game'),
    'BOOK_SNIPPET_READ':      _ActivityMeta(icon: Icons.menu_book_rounded,             color: Color(0xFF34D399), label: 'Reading'),
    'HABIT_CREATED':          _ActivityMeta(icon: Icons.add_task_rounded,              color: Color(0xFFA78BFA), label: 'Habit Created'),
    'HABIT_UPDATED':          _ActivityMeta(icon: Icons.edit_note_rounded,             color: Color(0xFF818CF8), label: 'Habit Updated'),
    'HABIT_DELETED':          _ActivityMeta(icon: Icons.delete_outline_rounded,        color: Color(0xFFFF5270), label: 'Habit Deleted'),
    'HABIT_COMPLETED':        _ActivityMeta(icon: Icons.check_circle_outline_rounded,  color: Color(0xFF10B981), label: 'Habit Done'),
    'FOCUS_ROOM_CREATED':     _ActivityMeta(icon: Icons.meeting_room_rounded,          color: Color(0xFFFFD166), label: 'Room Created'),
    'FOCUS_ROOM_JOINED':      _ActivityMeta(icon: Icons.groups_rounded,                color: Color(0xFFFB923C), label: 'Room Joined'),
  };

  static _ActivityMeta _meta(String type) =>
      _typeConfig[type] ??
      const _ActivityMeta(icon: Icons.circle_outlined, color: AppColors.primaryA, label: 'Activity');

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: meta.color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(meta.icon, color: meta.color, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              log.activityDescription ?? meta.label,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: meta.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(meta.label,
                    style: TextStyle(color: meta.color, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Text(_timeAgo(log.activityDate),
                  style: TextStyle(color: Colors.grey[600], fontSize: 11)),
            ]),
          ]),
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

// ── Score Ring Painter ─────────────────────────────────────────────────────────
class _ScoreRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  _ScoreRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 6;

    canvas.drawCircle(Offset(cx, cy), r,
        Paint()..color = Colors.white.withOpacity(0.06)..style = PaintingStyle.stroke..strokeWidth = 6);

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -math.pi / 2, 2 * math.pi * progress, false,
        Paint()
          ..color = color.withOpacity(0.2)..style = PaintingStyle.stroke..strokeWidth = 10
          ..strokeCap = StrokeCap.round..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -math.pi / 2, 2 * math.pi * progress, false,
        Paint()
          ..color = color..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ScoreRingPainter old) => old.progress != progress || old.color != color;
}

// ── Filter Chip (AI history) ───────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? activeColor.withOpacity(0.15) : const Color(0xFF0F1624),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? activeColor.withOpacity(0.6) : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? activeColor : Colors.grey[500],
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ── Book Filter Dropdown ───────────────────────────────────────────────────────
class _BookFilterDropdown extends StatelessWidget {
  final List<String> books;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _BookFilterDropdown({
    required this.books,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF818CF8);
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1624),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected != null
              ? accent.withOpacity(0.5)
              : Colors.white.withOpacity(0.1),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: selected,
          isDense: true,
          dropdownColor: const Color(0xFF111827),
          icon: Icon(
            Icons.expand_more_rounded,
            size: 16,
            color: selected != null ? accent : Colors.grey[500],
          ),
          hint: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.book_outlined, size: 13, color: Colors.grey[500]),
              const SizedBox(width: 5),
              Text('Book', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ],
          ),
          style: const TextStyle(color: Colors.white, fontSize: 12),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text('All Books', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            ),
            ...books.map((b) => DropdownMenuItem<String?>(
              value: b,
              child: Text(
                b.length > 22 ? '${b.substring(0, 20)}…' : b,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ── Snippet History Card ───────────────────────────────────────────────────────
class _SnippetHistoryCard extends StatelessWidget {
  final _SnippetHistoryItem item;
  const _SnippetHistoryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF818CF8);
    final result = item.attemptResult;
    final passed = result == 'PASSED';
    final failed = result == 'FAILED';
    final attempted = passed || failed;

    final badgeColor = passed
        ? const Color(0xFF10B981)
        : failed
            ? const Color(0xFFEF4444)
            : const Color(0xFF6B7A99);

    final badgeLabel = passed ? 'Passed' : failed ? 'Failed' : 'Pending';
    final badgeIcon  = passed
        ? Icons.check_circle_rounded
        : failed
            ? Icons.cancel_rounded
            : Icons.hourglass_empty_rounded;

    // Score label e.g. "2 / 3"
    final hasScore = attempted && item.correctCount != null && item.totalCount != null;
    final scoreLabel = hasScore ? '${item.correctCount} / ${item.totalCount}' : null;

    // Score percentage for progress bar (0.0 – 1.0)
    final scorePct = hasScore
        ? (item.correctCount! / item.totalCount!).clamp(0.0, 1.0)
        : 0.0;

    String? dateLabel;
    final dt = item.createdAt;
    if (dt != null) {
      final now  = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) {
        dateLabel = 'Just now';
      } else if (diff.inMinutes < 60) {
        dateLabel = '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        dateLabel = '${diff.inHours}h ago';
      } else if (diff.inDays < 7) {
        dateLabel = '${diff.inDays}d ago';
      } else {
        const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
        dateLabel = '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1624),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: passed
              ? const Color(0xFF10B981).withOpacity(0.2)
              : failed
                  ? const Color(0xFFEF4444).withOpacity(0.15)
                  : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left icon
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: accent, size: 18),
              ),
              const SizedBox(width: 12),

              // Middle content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.bookTitle,
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.snippetTitle,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Meta pills row
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.quiz_outlined, size: 11, color: accent.withOpacity(0.8)),
                          const SizedBox(width: 4),
                          Text(
                            '${item.questionCount} Q',
                            style: TextStyle(
                                color: accent.withOpacity(0.9),
                                fontSize: 10,
                                fontWeight: FontWeight.w600),
                          ),
                        ]),
                      ),
                      const SizedBox(width: 6),
                      if (dateLabel != null)
                        Text(dateLabel,
                            style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Right badge (result)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: badgeColor.withOpacity(0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(badgeIcon, size: 12, color: badgeColor),
                  const SizedBox(width: 4),
                  Text(
                    badgeLabel,
                    style: TextStyle(
                        color: badgeColor, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ]),
              ),
            ],
          ),

          // ── Score row (only when attempted and score data available) ──────────
          if (hasScore) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: scorePct,
                      minHeight: 5,
                      backgroundColor: Colors.white.withOpacity(0.06),
                      valueColor: AlwaysStoppedAnimation(badgeColor),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$scoreLabel correct',
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
