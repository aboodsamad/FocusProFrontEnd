import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../coaching/pages/coaching_page.dart';
import '../../coaching/models/daily_goal_model.dart';
import '../../coaching/services/coaching_service.dart';
import '../models/lock_in_session_model.dart';
import '../models/app_usage_stat_model.dart';
import '../services/lock_in_service.dart';
import '../services/android_lockin_helper.dart';

enum LockInState { setup, prep, active, summary }

class LockInPage extends StatefulWidget {
  final int? triggerScheduleId;
  final int? initialPrepMinutes;
  final int? initialDurationMinutes;

  const LockInPage({
    super.key,
    this.triggerScheduleId,
    this.initialPrepMinutes,
    this.initialDurationMinutes,
  });

  @override
  State<LockInPage> createState() => _LockInPageState();
}

class _LockInPageState extends State<LockInPage> with WidgetsBindingObserver {
  // Use named constant from AppColors instead of a magic inline hex value
  static const _dark = AppColors.lockInBackground;

  LockInState _state = LockInState.setup;
  LockInSessionModel? _session;

  // Setup options
  int _prepMinutes = 5;
  int _durationMinutes = 60;

  // Permissions
  bool _hasUsagePermission = false;

  // Countdown timers
  Timer? _prepTimer;
  Timer? _sessionTimer;
  Duration _prepRemaining = Duration.zero;
  Duration _sessionRemaining = Duration.zero;

  // Offline retry
  Timer? _offlineRetry;
  bool _offline = false;

  // Guard against _endSession being called twice (back gesture + timer)
  bool _sessionEnded = false;

  // Summary data
  bool _endedEarly = false;
  List<DailyGoalModel> _summaryGoals = [];
  List<AppUsageStatModel> _usageStats = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
    _checkForActiveSession();
  }

  Future<void> _checkPermissions() async {
    final has = await AndroidLockInHelper.hasUsageStatsPermission();
    if (mounted) setState(() => _hasUsagePermission = has);
  }

  Future<void> _checkForActiveSession() async {
    // Auto-start if triggered by alarm
    if (widget.triggerScheduleId != null) {
      final prep = widget.initialPrepMinutes ?? 5;
      final dur = widget.initialDurationMinutes ?? 60;
      final existing = await LockInService.getActiveSession();
      if (existing != null && mounted) {
        _session = existing;
        _enterStateFromSession(existing);
        return;
      }
      await _doStartLockIn(prep, dur, scheduleId: widget.triggerScheduleId);
      return;
    }

    // Check if there's already an active session to return to
    final active = await LockInService.getActiveSession();
    if (active != null && mounted) {
      setState(() => _session = active);
      _enterStateFromSession(active);
    }
  }

  void _enterStateFromSession(LockInSessionModel s) {
    final now = DateTime.now();
    if (s.isPrepPhase || now.isBefore(s.prepEndsAt)) {
      _startPrepFromSession(s);
    } else if (s.isActive) {
      _startActiveFromSession(s);
    }
  }

  // ── Setup ─────────────────────────────────────────────────────────────────

  Future<void> _onStartLockIn() async {
    await _doStartLockIn(_prepMinutes, _durationMinutes);
  }

  Future<void> _doStartLockIn(int prep, int duration, {int? scheduleId}) async {
    try {
      final session = await LockInService.startLockIn(prep, duration,
          scheduleId: scheduleId);
      if (!mounted) return;
      await AndroidLockInHelper.startScreenPin();
      await AndroidLockInHelper.acquireWakeLock();
      setState(() => _session = session);
      _startPrepFromSession(session);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start session. Check your connection.')),
        );
      }
    }
  }

  // ── Prep state ────────────────────────────────────────────────────────────

  void _startPrepFromSession(LockInSessionModel s) {
    final remaining = s.prepEndsAt.difference(DateTime.now());
    setState(() {
      _state = LockInState.prep;
      _prepRemaining = remaining.isNegative ? Duration.zero : remaining;
    });
    _startPrepTimer();
  }

  void _startPrepTimer() {
    _prepTimer?.cancel();
    _prepTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final remaining = _session!.prepEndsAt.difference(DateTime.now());
      if (remaining.isNegative || remaining.inSeconds <= 0) {
        _prepTimer?.cancel();
        _transitionToActive();
      } else {
        setState(() => _prepRemaining = remaining);
      }
    });
  }

  void _skipPrep() {
    _prepTimer?.cancel();
    _transitionToActive();
  }

  void _transitionToActive() {
    if (!mounted) return;
    _startActiveFromSession(_session!);
  }

  // ── Active state ──────────────────────────────────────────────────────────

  void _startActiveFromSession(LockInSessionModel s) {
    if (!mounted) return;
    final remaining = s.scheduledEndsAt.difference(DateTime.now());
    setState(() {
      _state = LockInState.active;
      _sessionRemaining = remaining.isNegative ? Duration.zero : remaining;
    });
    _startSessionTimer();
    _startOfflineRetry();
  }

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final remaining = _session!.scheduledEndsAt.difference(DateTime.now());
      if (remaining.isNegative || remaining.inSeconds <= 0) {
        _sessionTimer?.cancel();
        _autoEndSession();
      } else {
        setState(() => _sessionRemaining = remaining);
      }
    });
  }

  void _startOfflineRetry() {
    _offlineRetry?.cancel();
    _offlineRetry = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!mounted || _state != LockInState.active) return;
      // Connectivity check by attempting a lightweight API call
      final active = await LockInService.getActiveSession();
      if (mounted) setState(() => _offline = (active == null));
    });
  }

  Future<void> _autoEndSession() async {
    await _endSession(early: false);
  }

  Future<void> _confirmEndEarly() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('End your lock-in early?',
            style: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
        content: const Text(
          'Your screen pin will be released and the session will end.',
          style: TextStyle(color: AppColors.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _endSession(early: true);
  }

  Future<void> _endSession({required bool early}) async {
    // Prevent double-call from back gesture + timer firing simultaneously
    if (_sessionEnded) return;
    _sessionEnded = true;

    _sessionTimer?.cancel();
    _offlineRetry?.cancel();
    if (_session != null) {
      try {
        await LockInService.endLockIn(_session!.id, early);
      } catch (_) {}
    }
    await AndroidLockInHelper.stopScreenPin();
    await AndroidLockInHelper.releaseWakeLock();

    // Load summary data
    final goals = await _loadGoals();
    final stats = _hasUsagePermission
        ? await AndroidLockInHelper.getAppUsageToday()
        : <AppUsageStatModel>[];

    if (mounted) {
      setState(() {
        _endedEarly = early;
        _summaryGoals = goals;
        _usageStats = stats;
        _state = LockInState.summary;
      });
    }
  }

  Future<List<DailyGoalModel>> _loadGoals() async {
    try {
      final token = await AuthService.getToken() ?? '';
      if (token.isEmpty) return [];
      final goals = await CoachingService.getTodayGoals(token);
      return goals;
    } catch (_) {
      return [];
    }
  }

  // ── Lifecycle — release pin on app detach ────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      AndroidLockInHelper.stopScreenPin();
      AndroidLockInHelper.releaseWakeLock();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _prepTimer?.cancel();
    _sessionTimer?.cancel();
    _offlineRetry?.cancel();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case LockInState.setup:
        return _buildSetup();
      case LockInState.prep:
        return _buildPrep();
      case LockInState.active:
        return _buildActive();
      case LockInState.summary:
        return _buildSummary();
    }
  }

  // ── STATE: setup ──────────────────────────────────────────────────────────

  Widget _buildSetup() {
    return Scaffold(
      backgroundColor: _dark,
      appBar: AppBar(
        backgroundColor: _dark,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Wake-Up Mode',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.lockInCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Icon(Icons.alarm_rounded,
                      color: AppColors.secondary, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Start your morning lock-in',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'FocusPro will pin to your screen while you set your goals and focus',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Get ready timer selector
                  _buildSelectorRow(
                    label: 'Get ready timer',
                    options: const [5, 10, 15],
                    selected: _prepMinutes,
                    labelFn: (v) => '${v}m',
                    onSelect: (v) => setState(() => _prepMinutes = v),
                  ),
                  const SizedBox(height: 16),

                  // Focus duration selector
                  _buildSelectorRow(
                    label: 'Focus duration',
                    options: const [30, 60, 90, 120],
                    selected: _durationMinutes,
                    labelFn: (v) => v == 60
                        ? '1hr'
                        : v == 90
                            ? '1.5hr'
                            : v == 120
                                ? '2hr'
                                : '${v}m',
                    onSelect: (v) => setState(() => _durationMinutes = v),
                  ),
                  const SizedBox(height: 16),

                  // Usage stats permission banner
                  if (!_hasUsagePermission)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline,
                            color: Color(0xFFD97706), size: 16),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Grant usage access to see your screen time',
                            style: TextStyle(
                                color: Color(0xFF92400E), fontSize: 12),
                          ),
                        ),
                        TextButton(
                          onPressed:
                              AndroidLockInHelper.requestUsageStatsPermission,
                          style: TextButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8)),
                          child: const Text('Grant',
                              style: TextStyle(
                                  color: Color(0xFFD97706),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                      ]),
                    ),
                  const SizedBox(height: 24),

                  // Start button
                  GestureDetector(
                    onTap: _onStartLockIn,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.secondary, AppColors.primary],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Text('Start Lock-In',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectorRow<T>({
    required String label,
    required List<T> options,
    required T selected,
    required String Function(T) labelFn,
    required void Function(T) onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
        const SizedBox(height: 8),
        Row(
          children: options.map((opt) {
            final active = opt == selected;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onSelect(opt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.secondary.withValues(alpha: 0.2)
                        : AppColors.lockInBorder,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active
                          ? AppColors.secondary
                          : const Color(0xFF374151),
                    ),
                  ),
                  child: Text(
                    labelFn(opt),
                    style: TextStyle(
                      color:
                          active ? AppColors.secondary : AppColors.lockInMuted,
                      fontSize: 13,
                      fontWeight:
                          active ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── STATE: prep ───────────────────────────────────────────────────────────

  Widget _buildPrep() {
    final mins = _prepRemaining.inMinutes;
    final secs = _prepRemaining.inSeconds % 60;
    final timeStr =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: _dark,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Get ready...',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                timeStr,
                style: TextStyle(
                  color: AppColors.secondary,
                  fontSize: 72,
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Set your goals when the timer ends',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: _skipPrep,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.lockInMuted,
                  side: const BorderSide(color: Color(0xFF374151)),
                  shape: StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                ),
                child: const Text('Skip prep'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── STATE: active ─────────────────────────────────────────────────────────

  Widget _buildActive() {
    final mins = _sessionRemaining.inMinutes;
    final secs = _sessionRemaining.inSeconds % 60;
    final timeStr =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: _dark,
      body: Column(
        children: [
          // Persistent top banner
          SafeArea(
            bottom: false,
            child: Container(
              color: AppColors.lockInCard,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                if (_offline)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Text('Offline',
                        style: TextStyle(
                            color: Color(0xFFFBBF24),
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Lock-In Active',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  timeStr,
                  style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ]),
            ),
          ),

          // CoachingPage embedded (no AppBar)
          Expanded(
            child: CoachingPage(embedded: true),
          ),

          // Bottom persistent "End Session" bar
          Container(
            color: AppColors.lockInCard,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: _confirmEndEarly,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                  child: const Text('End Session',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── STATE: summary ────────────────────────────────────────────────────────

  Widget _buildSummary() {
    return Scaffold(
      backgroundColor: _dark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF10B981), size: 64),
              const SizedBox(height: 16),
              Text(
                _endedEarly ? 'Session ended early' : 'Session complete',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),

              // Goals list
              if (_summaryGoals.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Today's Goals",
                    style: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8),
                  ),
                ),
                const SizedBox(height: 10),
                ..._summaryGoals.map((g) => _buildGoalRow(g)),
                const SizedBox(height: 24),
              ],

              // Screen time section
              if (_hasUsagePermission && _usageStats.isNotEmpty)
                _buildScreenTimeSection(),

              const SizedBox(height: 32),

              // Done button
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.secondary, AppColors.primary],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text('Done',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalRow(DailyGoalModel goal) {
    Color statusColor;
    IconData statusIcon;
    switch (goal.status) {
      case 'DONE':
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'IN_PROGRESS':
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.timelapse_rounded;
        break;
      case 'SKIPPED':
        statusColor = AppColors.onSurfaceVariant;
        statusIcon = Icons.cancel_outlined;
        break;
      default:
        statusColor = const Color(0xFF6B7280);
        statusIcon = Icons.radio_button_unchecked;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.lockInCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.lockInBorder),
        ),
        child: Row(children: [
          Icon(statusIcon, color: statusColor, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(goal.goalText,
                style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
        ]),
      ),
    );
  }

  Widget _buildScreenTimeSection() {
    final top5 = _usageStats.take(5).toList();
    final maxMinutes =
        top5.isEmpty ? 1 : top5.map((s) => s.totalMinutesToday).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your screen time today',
          style: TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8),
        ),
        const SizedBox(height: 10),
        ...top5.map((stat) {
          final frac = maxMinutes > 0 ? stat.totalMinutesToday / maxMinutes : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(stat.appName,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text('${stat.totalMinutesToday}m',
                      style: const TextStyle(
                          color: Color(0xFF9CA3AF), fontSize: 12)),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: frac.clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: AppColors.lockInBorder,
                    valueColor: const AlwaysStoppedAnimation(AppColors.secondary),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }
}
