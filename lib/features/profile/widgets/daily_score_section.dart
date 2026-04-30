import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/daily_score_provider.dart';

class DailyScoreSection extends StatelessWidget {
  const DailyScoreSection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DailyScoreProvider>();
    final todayScore = provider.todayScore;
    final weekly = provider.weeklyScores;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.flash_on_rounded,
                    color: AppColors.secondary, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'Daily Progress',
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _TodayScoreCard(score: todayScore),
          const SizedBox(height: 16),
          _WeeklyChartCard(entries: weekly),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _TodayScoreCard extends StatelessWidget {
  final double score;
  const _TodayScoreCard({required this.score});

  @override
  Widget build(BuildContext context) {
    final hasScore = score > 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: hasScore
            ? const LinearGradient(
                colors: [Color(0xFF0E6C4A), Color(0xFF064D34)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: hasScore ? null : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: hasScore
                ? AppColors.secondary.withOpacity(0.3)
                : Colors.black.withOpacity(0.06),
            blurRadius: hasScore ? 24 : 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: hasScore
                  ? Colors.white.withOpacity(0.15)
                  : AppColors.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              hasScore ? Icons.bolt_rounded : Icons.bolt_outlined,
              color: hasScore ? Colors.white : AppColors.secondary,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's Score",
                  style: TextStyle(
                    color: hasScore
                        ? Colors.white.withOpacity(0.75)
                        : AppColors.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasScore
                      ? '+${score.toStringAsFixed(1)} pts'
                      : 'No activity yet',
                  style: TextStyle(
                    color: hasScore ? Colors.white : AppColors.onSurface,
                    fontSize: hasScore ? 28 : 18,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasScore
                      ? 'Keep it up — play a game or read a snippet!'
                      : 'Play a game or read a book snippet',
                  style: TextStyle(
                    color: hasScore
                        ? Colors.white.withOpacity(0.6)
                        : AppColors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (hasScore)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_fire_department_rounded,
                    color: Colors.white.withOpacity(0.85), size: 28),
                const SizedBox(height: 2),
                Text(
                  'Active',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _WeeklyChartCard extends StatelessWidget {
  final List<DailyScoreEntry> entries;
  const _WeeklyChartCard({required this.entries});

  @override
  Widget build(BuildContext context) {
    final maxScore   = entries.fold(0.0, (m, e) => math.max(m, e.score));
    final weekTotal  = entries.fold(0.0, (s, e) => s + e.score);
    final activeDays = entries.where((e) => e.score > 0).length;
    final avgScore   = activeDays > 0 ? weekTotal / activeDays : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This Week',
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    weekTotal > 0
                        ? '+${weekTotal.toStringAsFixed(0)} pts  ·  avg ${avgScore.toStringAsFixed(0)}/day'
                        : 'No activity this week yet',
                    style: const TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _StatPill(
                label: '$activeDays / 7',
                icon: Icons.calendar_today_rounded,
              ),
            ],
          ),
          const SizedBox(height: 22),

          // ── Chart ────────────────────────────────────────────────────────────
          SizedBox(
            height: 160,
            child: _BarChart(entries: entries, maxScore: maxScore),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final String label;
  final IconData icon;
  const _StatPill({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.secondary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.secondary.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.secondary, size: 11),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.secondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────

class _BarChart extends StatefulWidget {
  final List<DailyScoreEntry> entries;
  final double maxScore;
  const _BarChart({required this.entries, required this.maxScore});

  @override
  State<_BarChart> createState() => _BarChartState();
}

class _BarChartState extends State<_BarChart> {
  int? _tappedIdx;

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String _dayLabel(DateTime date) => _days[date.weekday - 1];

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final totalWidth  = constraints.maxWidth;
      final slotWidth   = totalWidth / widget.entries.length;
      final barWidth    = slotWidth * 0.52;
      // Layout zones inside the 160 px total height:
      //   20 px  — score pill row
      //    4 px  — gap
      //  108 px  — bar drawing area
      //    6 px  — gap
      //   14 px  — day label
      //    8 px  — today dot (shared with padding)
      const scorePillH = 20.0;
      const gapAbove   = 4.0;
      const barAreaH   = 106.0;
      const gapBelow   = 6.0;
      const dayLabelH  = 14.0;
      // total = 20+4+106+6+14 = 150 — fits inside 160 with margin

      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(widget.entries.length, (i) {
          final entry    = widget.entries[i];
          final today    = _isToday(entry.date);
          final tapped   = _tappedIdx == i;
          final hasScore = entry.score > 0;
          final ratio    = widget.maxScore > 0
              ? (entry.score / widget.maxScore).clamp(0.0, 1.0)
              : 0.0;
          final barH     = hasScore ? math.max(ratio * barAreaH, 8.0) : 4.0;

          // Colors
          final barGradient = today
              ? const LinearGradient(
                  colors: [Color(0xFF6EE7B7), Color(0xFF059669)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : hasScore
                  ? LinearGradient(
                      colors: [
                        AppColors.secondary.withOpacity(tapped ? 0.9 : 0.65),
                        AppColors.secondary.withOpacity(tapped ? 0.65 : 0.35),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    )
                  : null;

          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => setState(() => _tappedIdx = i),
              onTapUp: (_) =>
                  Future.delayed(const Duration(milliseconds: 180),
                      () { if (mounted) setState(() => _tappedIdx = null); }),
              onTapCancel: () => setState(() => _tappedIdx = null),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Score pill (always visible) ──────────────────────────
                  SizedBox(
                    height: scorePillH,
                    child: hasScore
                        ? Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: today
                                    ? AppColors.secondary.withOpacity(
                                        tapped ? 0.25 : 0.15)
                                    : tapped
                                        ? AppColors.surfaceContainerHigh
                                        : AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: today
                                      ? AppColors.secondary.withOpacity(0.45)
                                      : AppColors.outlineVariant
                                          .withOpacity(0.6),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                entry.score.toStringAsFixed(0),
                                style: TextStyle(
                                  color: today
                                      ? AppColors.secondary
                                      : AppColors.onSurfaceVariant,
                                  fontSize: 10,
                                  fontWeight: today
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  const SizedBox(height: gapAbove),

                  // ── Bar ────────────────────────────────────────────────────
                  SizedBox(
                    height: barAreaH,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        width: tapped ? barWidth * 1.12 : barWidth,
                        height: barH,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(hasScore ? 7 : 4),
                            topRight: Radius.circular(hasScore ? 7 : 4),
                            bottomLeft: const Radius.circular(4),
                            bottomRight: const Radius.circular(4),
                          ),
                          gradient: barGradient,
                          color: barGradient == null
                              ? AppColors.surfaceContainerHigh
                              : null,
                          boxShadow: today && hasScore
                              ? [
                                  BoxShadow(
                                    color:
                                        AppColors.secondary.withOpacity(0.45),
                                    blurRadius: 12,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : tapped && hasScore
                                  ? [
                                      BoxShadow(
                                        color: AppColors.secondary
                                            .withOpacity(0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: gapBelow),

                  // ── Day label ──────────────────────────────────────────────
                  SizedBox(
                    height: dayLabelH,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _dayLabel(entry.date),
                          style: TextStyle(
                            color: today
                                ? AppColors.secondary
                                : AppColors.onSurfaceVariant,
                            fontSize: 10,
                            fontWeight: today
                                ? FontWeight.w800
                                : FontWeight.w400,
                          ),
                        ),
                        if (today) ...[
                          const SizedBox(height: 2),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.secondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      );
    });
  }
}
