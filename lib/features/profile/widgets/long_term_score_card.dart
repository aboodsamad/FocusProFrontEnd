import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../home/providers/user_provider.dart';

// ── Tier definitions ──────────────────────────────────────────────────────────
class _Tier {
  final String label;
  final String emoji;
  final double min;
  final double max;
  final Color color;
  const _Tier(this.label, this.emoji, this.min, this.max, this.color);
}

const _tiers = [
  _Tier('Beginner',       '🌱', 0,  25,  Color(0xFFEF4444)),
  _Tier('Building',       '🔧', 26, 45,  Color(0xFFF97316)),
  _Tier('Consistent',     '⚡', 46, 65,  Color(0xFFF59E0B)),
  _Tier('High Performer', '🔥', 66, 80,  Color(0xFF10B981)),
  _Tier('Elite',          '🏆', 81, 100, Color(0xFF0E6C4A)),
];

_Tier _tierFor(double score) {
  for (final t in _tiers) {
    if (score <= t.max) return t;
  }
  return _tiers.last;
}

// ── Public widget ─────────────────────────────────────────────────────────────
class LongTermScoreCard extends StatelessWidget {
  const LongTermScoreCard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final score = user.longTermScore;
    final trend = user.weekTrend;
    final hasScore = score > 1.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.insights_rounded,
                    color: AppColors.primary, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'Long-Term Score',
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              _InfoChip(trend: trend),
            ],
          ),
          const SizedBox(height: 16),

          // ── Main card ───────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: hasScore
                ? _ScoreGauge(score: score, trend: trend)
                : _NoDiagnosticPlaceholder(),
          ),
        ],
      ),
    );
  }
}

// ── Info chip (week trend) ────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final double? trend;
  const _InfoChip({required this.trend});

  @override
  Widget build(BuildContext context) {
    if (trend == null) return const SizedBox.shrink();
    final up = trend! >= 0;
    final abs = trend!.abs();
    if (abs < 0.1) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (up ? AppColors.secondary : AppColors.error).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (up ? AppColors.secondary : AppColors.error).withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 13,
            color: up ? AppColors.secondary : AppColors.error,
          ),
          const SizedBox(width: 4),
          Text(
            '${up ? '+' : '−'}${abs.toStringAsFixed(1)} this week',
            style: TextStyle(
              color: up ? AppColors.secondary : AppColors.error,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Gauge layout ──────────────────────────────────────────────────────────────
class _ScoreGauge extends StatelessWidget {
  final double score;
  final double? trend;
  const _ScoreGauge({required this.score, required this.trend});

  @override
  Widget build(BuildContext context) {
    final tier = _tierFor(score);
    final nextTier = _tiers.firstWhere(
      (t) => t.min > score,
      orElse: () => _tiers.last,
    );
    final ptsToNext = (nextTier.min - score).clamp(0.0, 100.0);

    return Column(
      children: [
        // Arc gauge
        SizedBox(
          width: 220,
          height: 140,
          child: CustomPaint(
            painter: _ArcGaugePainter(score: score),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      score.toInt().toString(),
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        letterSpacing: -2,
                      ),
                    ),
                    Text(
                      '/ 100',
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant.withOpacity(0.6),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Tier badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: tier.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: tier.color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tier.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                tier.label,
                style: TextStyle(
                  color: tier.color,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Tier progress row
        if (score < 100) ...[
          _TierProgressRow(
            tiers: _tiers,
            score: score,
          ),
          const SizedBox(height: 12),
          if (ptsToNext > 0)
            Text(
              '${ptsToNext.toInt()} pts to ${nextTier.label}',
              style: const TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
        ],

        const SizedBox(height: 16),

        // How it works row
        _HowItWorksRow(),
      ],
    );
  }
}

// ── Tier progress bar ─────────────────────────────────────────────────────────
class _TierProgressRow extends StatelessWidget {
  final List<_Tier> tiers;
  final double score;
  const _TierProgressRow({required this.tiers, required this.score});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 8,
            child: LayoutBuilder(
              builder: (_, constraints) {
                final totalW = constraints.maxWidth;
                return Stack(
                  children: [
                    Container(
                      width: totalW, height: 8,
                      color: AppColors.surfaceContainerHigh,
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      width: totalW * (score / 100).clamp(0.0, 1.0),
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFEF4444),
                            const Color(0xFFF97316),
                            const Color(0xFFF59E0B),
                            const Color(0xFF10B981),
                            AppColors.secondary,
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: tiers.map((t) => Text(
            t.label.split(' ').first, // first word only
            style: TextStyle(
              color: score >= t.min
                  ? AppColors.onSurfaceVariant
                  : AppColors.outlineVariant,
              fontSize: 9,
              fontWeight: score >= t.min ? FontWeight.w600 : FontWeight.w400,
            ),
          )).toList(),
        ),
      ],
    );
  }
}

// ── How it works ──────────────────────────────────────────────────────────────
class _HowItWorksRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 14, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Updates daily. Earn 50+ pts/day to grow fast. '
              'Consistent training beats one-off sessions.',
              style: const TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── No diagnostic placeholder ────────────────────────────────────────────────
class _NoDiagnosticPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Icon(Icons.psychology_outlined,
              size: 48, color: AppColors.outlineVariant),
          const SizedBox(height: 12),
          const Text(
            'Complete the diagnostic first',
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your cognitive baseline sets the starting point\nfor the long-term score.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}

// ── Arc gauge painter ─────────────────────────────────────────────────────────
class _ArcGaugePainter extends CustomPainter {
  final double score;
  const _ArcGaugePainter({required this.score});

  static const double _startDeg  = 145.0;
  static const double _sweepDeg  = 250.0;
  static const double _strokeW   = 13.0;

  static const List<Color> _gaugeColors = [
    Color(0xFFEF4444), // red    — Beginner
    Color(0xFFF97316), // orange — Building
    Color(0xFFF59E0B), // amber  — Consistent
    Color(0xFF10B981), // green  — High Performer
    Color(0xFF0E6C4A), // deep   — Elite
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 10;
    final r  = math.min(cx, cy) - _strokeW;

    final startRad = _startDeg * math.pi / 180;
    final sweepRad = _sweepDeg * math.pi / 180;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // ── Background track ───────────────────────────────────────────────────
    canvas.drawArc(
      rect, startRad, sweepRad, false,
      Paint()
        ..color = AppColors.surfaceContainerHigh
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeW
        ..strokeCap = StrokeCap.round,
    );

    // ── Filled arc with sweep gradient ────────────────────────────────────
    final fill = sweepRad * (score / 100).clamp(0.0, 1.0);
    if (fill > 0.01) {
      canvas.drawArc(
        rect, startRad, fill, false,
        Paint()
          ..shader = SweepGradient(
            startAngle: startRad,
            endAngle: startRad + sweepRad,
            colors: _gaugeColors,
            stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
          ).createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strokeW
          ..strokeCap = StrokeCap.round,
      );

      // ── Glowing tip dot ────────────────────────────────────────────────
      final tipAngle = startRad + fill;
      final tipX = cx + r * math.cos(tipAngle);
      final tipY = cy + r * math.sin(tipAngle);
      final tipColor = _colorForScore(score);

      canvas.drawCircle(
        Offset(tipX, tipY), 11,
        Paint()
          ..color = tipColor.withOpacity(0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(Offset(tipX, tipY), 7,
          Paint()..color = Colors.white);
      canvas.drawCircle(Offset(tipX, tipY), 5,
          Paint()..color = tipColor);
    }
  }

  Color _colorForScore(double s) {
    if (s >= 81) return const Color(0xFF0E6C4A);
    if (s >= 66) return const Color(0xFF10B981);
    if (s >= 46) return const Color(0xFFF59E0B);
    if (s >= 26) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }

  @override
  bool shouldRepaint(_ArcGaugePainter old) => old.score != score;
}
