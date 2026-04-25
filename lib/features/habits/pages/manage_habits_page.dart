import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../models/habit.dart';
import '../providers/habit_provider.dart';
import '../widgets/add_habit_sheet.dart';

class ManageHabitsPage extends StatelessWidget {
  const ManageHabitsPage({Key? key}) : super(key: key);

  // ── helpers ─────────────────────────────────────────────────────────────────

  /// Dynamic header title based on done / total ratio.
  static String _headerTitle(int done, int total) {
    if (total == 0) return 'Let\'s Get Started';
    final ratio = done / total;
    if (ratio >= 1.0) return 'Flow State!';
    if (ratio >= 0.6) return 'Steady Progress';
    if (ratio > 0) return 'Keep Going';
    return 'Ready to Focus';
  }

  // ── public entry for add-habit sheet ────────────────────────────────────────
  void _showHabitSheet(BuildContext context, Habit? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        // Respect keyboard insets at sheet level
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: AddHabitSheet(
          existing: existing,
          onSave: (habit) {
            final provider = context.read<HabitProvider>();
            if (existing == null) {
              provider.add(habit);
            } else {
              provider.editSafe(existing, habit);
            }
          },
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, HabitProvider provider, Habit habit) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Habit',
            style: TextStyle(
                color: AppColors.onSurface, fontWeight: FontWeight.bold)),
        content: Text(
          'Delete "${habit.title}"? This cannot be undone.',
          style: const TextStyle(color: AppColors.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(context);
              provider.delete(habit);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── build ────────────────────────────────────────────────────────────────────
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
      bottomNavigationBar: const AppBottomNav(current: NavTab.habits),
      body: Consumer<HabitProvider>(
        builder: (context, provider, _) {
          // Loading
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final done  = provider.doneCount;
          final total = provider.totalCount;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── App bar / hero header ─────────────────────────────────────
              _HabitsAppBar(
                title: _headerTitle(done, total),
                subtitle: done >= total && total > 0
                    ? 'You\'ve reached your flow state.'
                    : 'Track your daily habits below.',
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 16),

                    // ── Progress summary card ──────────────────────────────
                    _ProgressCard(done: done, total: total),
                    const SizedBox(height: 16),

                    // ── Habit cards ────────────────────────────────────────
                    if (provider.habits.isEmpty)
                      _EmptyState(
                          onAdd: () => _showHabitSheet(context, null))
                    else
                      ...provider.habits.map((habit) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _HabitCard(
                              habit: habit,
                              onToggle: () async {
                                HapticFeedback.lightImpact();
                                final err = await provider.toggle(habit);
                                if (err != null && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(err),
                                      backgroundColor: Colors.red.shade600,
                                    ),
                                  );
                                }
                              },
                              onEdit: () =>
                                  _showHabitSheet(context, habit),
                              onDelete: () => _confirmDelete(
                                  context, provider, habit),
                            ),
                          )),

                    // ── Pro Insight banner ─────────────────────────────────
                    if (provider.habits.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      const _ProInsightBanner(),
                      const SizedBox(height: 20),
                    ],

                    // ── + New Habit card ───────────────────────────────────
                    _NewHabitCard(
                        onTap: () => _showHabitSheet(context, null)),
                    const SizedBox(height: 24),

                    // ── Upcoming section ───────────────────────────────────
                    if (provider.habits.isNotEmpty)
                      _UpcomingSection(
                        habits: provider.habits,
                        onToggle: (h) async {
                          HapticFeedback.lightImpact();
                          final err = await provider.toggle(h);
                          if (err != null && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(err),
                                backgroundColor: Colors.red.shade600,
                              ),
                            );
                          }
                        },
                      ),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    ));
  }
}

// ── App bar ───────────────────────────────────────────────────────────────────
class _HabitsAppBar extends StatelessWidget {
  final String title;
  final String subtitle;
  const _HabitsAppBar({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.fromLTRB(
            20, MediaQuery.of(context).padding.top + 16, 20, 20),
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          boxShadow: [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Progress summary card ─────────────────────────────────────────────────────
class _ProgressCard extends StatelessWidget {
  final int done;
  final int total;
  const _ProgressCard({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0.0 : done / total;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          // Circular progress
          SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: percent,
                  strokeWidth: 6,
                  backgroundColor: AppColors.outlineVariant,
                  color: AppColors.primary,
                ),
                Center(
                  child: Text(
                    '${(percent * 100).round()}%',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$done/$total Habits Done',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Daily Goal Tracking',
                style: TextStyle(
                    color: AppColors.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Habit card ────────────────────────────────────────────────────────────────
class _HabitCard extends StatelessWidget {
  final Habit habit;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  const _HabitCard({
    required this.habit,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final h         = habit;
    final color     = _categoryColor(h.category);
    final today     = DateTime.now().weekday; // 1=Mon…7=Sun
    final todayIdx  = today - 1;

    return Dismissible(
      key: ValueKey(h.id ?? h.title),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: AppColors.error, size: 24),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: GestureDetector(
        onTap: onEdit,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 8,
                  offset: Offset(0, 2))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row: avatar | name + streak | checkmark ────────────
              Row(
                children: [
                  // Colored avatar
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(h.icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  // Name + streak
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          h.title,
                          style: const TextStyle(
                            color: AppColors.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (h.streak > 0) ...[
                          const SizedBox(height: 3),
                          Text(
                            '🔥 ${h.streak} days',
                            style: const TextStyle(
                                color: AppColors.onSurfaceVariant,
                                fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Done-today checkmark (tappable)
                  GestureDetector(
                    onTap: onToggle,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: h.doneToday
                            ? AppColors.secondary
                            : Colors.transparent,
                        border: h.doneToday
                            ? null
                            : Border.all(
                                color: AppColors.outlineVariant, width: 2),
                      ),
                      child: h.doneToday
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 18)
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── "THIS WEEK" label ──────────────────────────────────────
              const Text(
                'THIS WEEK',
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),

              // ── Day circles ────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (i) {
                  final scheduled = h.days[i];
                  final isToday   = i == todayIdx;
                  final isDone    = scheduled && isToday && h.doneToday;

                  // Visual state:
                  // 1. Completed (done today)  → primaryContainer bg, white text
                  // 2. Today not done          → outlined, primary color text
                  // 3. Scheduled past/future   → surfaceContainerLow bg, variant text
                  // 4. Not scheduled           → outlineVariant text only

                  Color? bgColor;
                  Color textColor;
                  Border? border;

                  if (isDone) {
                    bgColor   = AppColors.primaryContainer;
                    textColor = Colors.white;
                  } else if (isToday && scheduled) {
                    bgColor   = Colors.transparent;
                    textColor = AppColors.primary;
                    border = Border.all(
                        color: AppColors.primary, width: 1.5);
                  } else if (scheduled) {
                    bgColor   = AppColors.surfaceContainerLow;
                    textColor = AppColors.onSurfaceVariant;
                  } else {
                    bgColor   = AppColors.surfaceContainerLow;
                    textColor = AppColors.outlineVariant;
                  }

                  return Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: bgColor,
                      border: border,
                    ),
                    child: Center(
                      child: Text(
                        _dayLabels[i],
                        style: TextStyle(
                          color: textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }),
              ),

              // ── Edit / delete actions ──────────────────────────────────
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ActionBtn(
                    icon: Icons.edit_outlined,
                    color: AppColors.secondary,
                    onTap: onEdit,
                  ),
                  const SizedBox(width: 8),
                  _ActionBtn(
                    icon: Icons.delete_outline_rounded,
                    color: AppColors.error,
                    onTap: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'learning': return AppColors.secondary;
      case 'focus':    return const Color(0xFF10B981);
      case 'digital':  return const Color(0xFFEF4444);
      case 'wellness': return const Color(0xFFF97316);
      case 'fitness':  return const Color(0xFF06B6D4);
      default:         return const Color(0xFFEC4899);
    }
  }
}

// ── Small action button ────────────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
      );
}

// ── Pro Insight banner ────────────────────────────────────────────────────────
class _ProInsightBanner extends StatelessWidget {
  const _ProInsightBanner();

  static const List<String> _quotes = [
    '"Small daily improvements\nare the key to staggering\nlong-term results."',
    '"We are what we repeatedly do.\nExcellence is not an act,\nbut a habit."',
    '"The secret of your future\nis hidden in your\ndaily routine."',
    '"Motivation gets you going,\nbut habit keeps you\ngrowing."',
  ];

  @override
  Widget build(BuildContext context) {
    // Pick a deterministic quote based on the day of year
    final quote = _quotes[DateTime.now().dayOfYear % _quotes.length];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'PRO INSIGHT',
              style: TextStyle(
                color: AppColors.onSecondaryContainer,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Quote
          Text(
            quote,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Consistency beats intensity every time.',
            style: TextStyle(
                color: AppColors.onPrimaryContainer, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── + New Habit card ──────────────────────────────────────────────────────────
class _NewHabitCard extends StatelessWidget {
  final VoidCallback onTap;
  const _NewHabitCard({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.outlineVariant,
              width: 1.5,
              // Dashed look via a custom painter would be ideal; using solid
              // here for simplicity while matching the color spec.
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline_rounded,
                  color: AppColors.primary, size: 22),
              SizedBox(width: 8),
              Text(
                'New Habit',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
}

// ── Dashed-border painter (used by _NewHabitCard) ─────────────────────────────
// Unused if you use solid border above; kept for reference.
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLen;
  final double gapLen;
  final double radius;

  const _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.dashLen = 6,
    this.gapLen = 4,
    this.radius = 12,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(radius)));
    _drawDashed(canvas, path, paint);
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint) {
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double dist = 0;
      while (dist < metric.length) {
        final end = math.min(dist + dashLen, metric.length);
        canvas.drawPath(metric.extractPath(dist, end), paint);
        dist += dashLen + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.checklist_rounded,
                  color: AppColors.primary, size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              'No habits yet',
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your first habit to start building streaks',
              style:
                  TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: onAdd,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
              ),
              child: const Text('Add First Habit',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ],
        ),
      );
}

// ── Upcoming section ──────────────────────────────────────────────────────────
class _UpcomingSection extends StatelessWidget {
  final List<Habit> habits;
  final Future<void> Function(Habit) onToggle;  // callers handle error display

  const _UpcomingSection(
      {required this.habits, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    // Show habits not yet done today that are scheduled today
    final today = DateTime.now().weekday - 1; // 0=Mon…6=Sun
    final upcoming = habits
        .where((h) => h.days[today] && !h.doneToday)
        .toList();

    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upcoming',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...upcoming.map((h) => _UpcomingRow(
              habit: h,
              onToggle: () => onToggle(h),
            )),
      ],
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  final Habit habit;
  final VoidCallback onToggle;
  const _UpcomingRow({required this.habit, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final color = _catColor(habit.category);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 6,
                offset: Offset(0, 1))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(habit.icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.title,
                    style: const TextStyle(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                  if (habit.streak > 0)
                    Text('🔥 ${habit.streak} days',
                        style: const TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 11)),
                ],
              ),
            ),
            GestureDetector(
              onTap: onToggle,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.outlineVariant, width: 1.5),
                ),
                child: const Icon(Icons.check,
                    color: AppColors.outlineVariant, size: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _catColor(String cat) {
    switch (cat) {
      case 'learning': return AppColors.secondary;
      case 'focus':    return const Color(0xFF10B981);
      case 'digital':  return const Color(0xFFEF4444);
      case 'wellness': return const Color(0xFFF97316);
      case 'fitness':  return const Color(0xFF06B6D4);
      default:         return const Color(0xFFEC4899);
    }
  }
}

// ── DateTime extension ─────────────────────────────────────────────────────────
extension _DayOfYear on DateTime {
  int get dayOfYear {
    final start = DateTime(year, 1, 1);
    return difference(start).inDays;
  }
}
