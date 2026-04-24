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
          // ── Section header ──────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.flash_on_rounded,
                  color: AppColors.secondary,
                  size: 16,
                ),
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

          // ── Today's score card ──────────────────────────────────────────────
          _TodayScoreCard(score: todayScore),
          const SizedBox(height: 16),

          // ── Weekly chart card ───────────────────────────────────────────────
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
          // ── Icon ────────────────────────────────────────────────────────────
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

          // ── Score info ───────────────────────────────────────────────────────
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
                if (hasScore) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Keep it up — play a game or read a snippet!',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 11,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Play a game or read a book snippet',
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Flame streak indicator ────────────────────────────────────────────
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
    final maxScore = entries.fold(0.0, (m, e) => math.max(m, e.score));
    final weekTotal = entries.fold(0.0, (s, e) => s + e.score);
    final activeDays = entries.where((e) => e.score > 0).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              const Text(
                'This Week',
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              _StatPill(
                label: '$activeDays / 7 days active',
                icon: Icons.calendar_today_rounded,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            weekTotal > 0
                ? '+${weekTotal.toStringAsFixed(1)} pts total this week'
                : 'No activity this week yet',
            style: const TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),

          // ── Bar chart ──────────────────────────────────────────────────────
          SizedBox(
            height: 120,
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.secondary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.secondary.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.secondary, size: 12),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.secondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────

class _BarChart extends StatelessWidget {
  final List<DailyScoreEntry> entries;
  final double maxScore;

  const _BarChart({required this.entries, required this.maxScore});

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String _dayLabel(DateTime date) {
    return _days[date.weekday - 1];
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final barAreaWidth = totalWidth / entries.length;
        final barWidth = barAreaWidth * 0.45;
        final chartHeight = constraints.maxHeight - 26; // reserve space for labels

        return Stack(
          children: [
            // ── Horizontal guide lines ─────────────────────────────────────
            CustomPaint(
              size: Size(totalWidth, chartHeight),
              painter: _GuideLinePainter(),
            ),

            // ── Bars ────────────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(entries.length, (i) {
                final entry = entries[i];
                final today = _isToday(entry.date);
                final ratio = maxScore > 0 ? (entry.score / maxScore).clamp(0.0, 1.0) : 0.0;
                final barH = ratio * chartHeight;
                final hasScore = entry.score > 0;

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Score label above bar
                      SizedBox(
                        height: chartHeight - (hasScore ? barH : 0),
                        child: hasScore
                            ? Align(
                                alignment: Alignment.bottomCenter,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    entry.score.toStringAsFixed(0),
                                    style: TextStyle(
                                      color: today
                                          ? AppColors.secondary
                                          : AppColors.onSurfaceVariant,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),

                      // Bar itself
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        width: barWidth,
                        height: hasScore ? barH : 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          gradient: today
                              ? const LinearGradient(
                                  colors: [Color(0xFF34D399), Color(0xFF0E6C4A)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                )
                              : hasScore
                                  ? LinearGradient(
                                      colors: [
                                        AppColors.secondary.withOpacity(0.55),
                                        AppColors.secondary.withOpacity(0.3),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    )
                                  : null,
                          color: (!hasScore && !today)
                              ? AppColors.surfaceContainerHigh
                              : null,
                          boxShadow: today && hasScore
                              ? [
                                  BoxShadow(
                                    color: AppColors.secondary.withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                      ),

                      // Day label
                      const SizedBox(height: 6),
                      Text(
                        _dayLabel(entry.date),
                        style: TextStyle(
                          color: today
                              ? AppColors.secondary
                              : AppColors.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight:
                              today ? FontWeight.bold : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _GuideLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.outlineVariant.withOpacity(0.4)
      ..strokeWidth = 0.8;

    final lines = 3;
    for (int i = 0; i <= lines; i++) {
      final y = size.height * (1 - i / lines);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GuideLinePainter old) => false;
}
