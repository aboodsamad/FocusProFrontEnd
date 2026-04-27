import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../models/app_usage_stat_model.dart';
import '../services/android_lockin_helper.dart';
import '../services/screen_event_service.dart';

class ScreenTimeStatsPage extends StatefulWidget {
  const ScreenTimeStatsPage({super.key});

  @override
  State<ScreenTimeStatsPage> createState() => _ScreenTimeStatsPageState();
}

class _ScreenTimeStatsPageState extends State<ScreenTimeStatsPage> {
  List<AppUsageStatModel> _stats = [];
  bool _loading = true;
  String? _error;
  DateTime _lastRefresh = DateTime.now();

  // System/launcher packages to hide from the list
  static const _systemPrefixes = [
    'com.android.systemui',
    'com.android.launcher',
    'com.google.android.launcher',
    'com.sec.android.app.launcher',
    'com.miui.home',
    'com.android.permissioncontroller',
    'com.google.android.permissioncontroller',
    'com.android.packageinstaller',
    'com.android.settings',
    'com.google.android.inputmethod',
    'com.samsung.android.inputmethod',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Try local device data first (most accurate)
      final local = await AndroidLockInHelper.getAppUsageToday();
      if (local.isNotEmpty) {
        setState(() {
          _stats = _filter(local);
          _loading = false;
          _lastRefresh = DateTime.now();
        });
        return;
      }

      // Fallback to backend summary
      final remote = await ScreenEventService.getSummary();
      if (remote.isNotEmpty) {
        final mapped = remote
            .map(
              (m) => AppUsageStatModel(
                packageName: m['packageName'] as String? ?? '',
                appName: m['appName'] as String? ?? '',
                totalMinutesToday: (m['totalMinutes'] as num? ?? 0).toInt(),
              ),
            )
            .toList();
        setState(() {
          _stats = _filter(mapped);
          _loading = false;
          _lastRefresh = DateTime.now();
        });
        return;
      }

      setState(() {
        _stats = [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load screen time data.';
        _loading = false;
      });
    }
  }

  List<AppUsageStatModel> _filter(List<AppUsageStatModel> raw) {
    return raw
        .where((s) => s.totalMinutesToday > 0 && !_systemPrefixes.any((p) => s.packageName.startsWith(p)))
        .toList()
      ..sort((a, b) => b.totalMinutesToday.compareTo(a.totalMinutesToday));
  }

  int get _totalMinutes => _stats.fold(0, (sum, s) => sum + s.totalMinutesToday);

  String _formatTime(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  String _formatHHMM(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  Color _appColor(String packageName) {
    const palette = [
      Color(0xFF6366F1),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFF8B5CF6),
      Color(0xFF3B82F6),
      Color(0xFFF97316),
      Color(0xFFEC4899),
      Color(0xFF14B8A6),
      Color(0xFF84CC16),
    ];
    return palette[packageName.hashCode.abs() % palette.length];
  }

  IconData _appIcon(String packageName) {
    if (packageName.contains('instagram') ||
        packageName.contains('tiktok') ||
        packageName.contains('snapchat') ||
        packageName.contains('twitter') ||
        packageName.contains('facebook') ||
        packageName.contains('whatsapp') ||
        packageName.contains('telegram') ||
        packageName.contains('discord')) {
      return Icons.chat_bubble_rounded;
    }
    if (packageName.contains('youtube') ||
        packageName.contains('netflix') ||
        packageName.contains('spotify') ||
        packageName.contains('twitch') ||
        packageName.contains('video') ||
        packageName.contains('music')) {
      return Icons.play_circle_rounded;
    }
    if (packageName.contains('chrome') ||
        packageName.contains('browser') ||
        packageName.contains('firefox') ||
        packageName.contains('safari')) {
      return Icons.language_rounded;
    }
    if (packageName.contains('teams') ||
        packageName.contains('slack') ||
        packageName.contains('zoom') ||
        packageName.contains('meet')) {
      return Icons.groups_rounded;
    }
    if (packageName.contains('gmail') || packageName.contains('mail') || packageName.contains('outlook')) {
      return Icons.mail_rounded;
    }
    if (packageName.contains('maps') || packageName.contains('navigation')) {
      return Icons.map_rounded;
    }
    if (packageName.contains('camera') || packageName.contains('gallery') || packageName.contains('photos')) {
      return Icons.photo_camera_rounded;
    }
    if (packageName.contains('LockedIn') || packageName.contains('capstone')) {
      return Icons.psychology_rounded;
    }
    return Icons.apps_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.secondary, strokeWidth: 2.5))
                    : _error != null
                    ? _buildError()
                    : _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.onSurface),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Screen Time',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.onSurface),
            ),
          ),
          GestureDetector(
            onTap: _load,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.secondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.outlineVariant),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_stats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(color: AppColors.surfaceContainerLow, shape: BoxShape.circle),
                child: const Icon(Icons.phone_android_rounded, size: 36, color: AppColors.outlineVariant),
              ),
              const SizedBox(height: 20),
              const Text(
                'No screen time data yet',
                style: TextStyle(color: AppColors.onSurface, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Grant Usage Access permission and use your phone for a bit.',
                style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final total = _totalMinutes;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildTotalCard(total),
        const SizedBox(height: 24),
        _buildSectionLabel('APP BREAKDOWN'),
        const SizedBox(height: 10),
        ..._stats.asMap().entries.map(
          (e) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _buildAppRow(e.value, total, e.key)),
        ),
        const SizedBox(height: 8),
        Text(
          'Last refreshed at ${_lastRefresh.hour.toString().padLeft(2, '0')}:${_lastRefresh.minute.toString().padLeft(2, '0')}',
          style: const TextStyle(color: AppColors.outline, fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTotalCard(int total) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Screen Time',
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatHHMM(total),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    height: 1,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 4),
                Text('Today  •  ${_stats.length} apps', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.phone_android_rounded, size: 56, color: Colors.white24),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.outline, letterSpacing: 1.0),
    );
  }

  Widget _buildAppRow(AppUsageStatModel stat, int total, int index) {
    final pct = total == 0 ? 0.0 : stat.totalMinutesToday / total;
    final color = _appColor(stat.packageName);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          // App icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(_appIcon(stat.packageName), color: color, size: 22),
          ),
          const SizedBox(width: 14),

          // Name + bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        stat.appName.isNotEmpty ? stat.appName : stat.packageName.split('.').last,
                        style: const TextStyle(color: AppColors.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(stat.totalMinutesToday),
                      style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 5,
                    backgroundColor: AppColors.surfaceContainerHigh,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(pct * 100).toStringAsFixed(1)}% of total',
                  style: const TextStyle(color: AppColors.outline, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
