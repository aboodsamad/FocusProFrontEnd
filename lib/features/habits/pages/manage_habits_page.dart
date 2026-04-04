import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../models/habit.dart';
import '../providers/habit_provider.dart';

class ManageHabitsPage extends StatelessWidget {
  const ManageHabitsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080D1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Habits',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => _showHabitDialog(context, null),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [AppColors.primaryA, AppColors.primaryB]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text('Add', style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Consumer<HabitProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryA),
            );
          }

          if (provider.habits.isEmpty) {
            return _EmptyState(onAdd: () => _showHabitDialog(context, null));
          }

          return Column(
            children: [
              _ProgressHeader(provider: provider),
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: provider.habits.length,
                  itemBuilder: (ctx, i) {
                    final habit = provider.habits[i];
                    return _HabitCard(
                      habit: habit,
                      onToggle: () => provider.toggle(habit),
                      onEdit: () => _showHabitDialog(context, habit),
                      onDelete: () => _confirmDelete(context, provider, habit),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showHabitDialog(context, null),
        backgroundColor: AppColors.primaryA,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _confirmDelete(BuildContext context, HabitProvider provider, Habit habit) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F1624),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Habit', style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete "${habit.title}"? This cannot be undone.',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[500])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  void _showHabitDialog(BuildContext context, Habit? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HabitFormSheet(
        existing: existing,
        onSave: (habit) {
          final provider = context.read<HabitProvider>();
          if (existing == null) {
            provider.add(habit);
          } else {
            provider.edit(existing, habit);
          }
        },
      ),
    );
  }
}

// ── Progress header ──────────────────────────────────────────────────────────
class _ProgressHeader extends StatelessWidget {
  final HabitProvider provider;
  const _ProgressHeader({required this.provider});

  @override
  Widget build(BuildContext context) {
    final done = provider.doneCount;
    final total = provider.totalCount;
    final pct = total == 0 ? 0.0 : done / total;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1624),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primaryA.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: AppColors.primaryA.withOpacity(0.08),
              blurRadius: 20, spreadRadius: 2)
        ],
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Today's Progress",
                  style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 2),
              Text('$done of $total habits completed',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ]),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: pct == 1.0
                    ? const Color(0xFF10B981).withOpacity(0.15)
                    : AppColors.primaryA.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                pct == 1.0 ? '🎉 All done!' : '${(pct * 100).round()}%',
                style: TextStyle(
                  color: pct == 1.0 ? const Color(0xFF10B981) : AppColors.primaryA,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pct),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (_, value, __) => LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.06),
              valueColor: AlwaysStoppedAnimation(
                  pct == 1.0 ? const Color(0xFF10B981) : AppColors.primaryA),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Habit card ───────────────────────────────────────────────────────────────
class _HabitCard extends StatefulWidget {
  final Habit habit;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _HabitCard({
    required this.habit,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends State<_HabitCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final h = widget.habit;
    final color = _categoryColor(h.category);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey(h.id ?? h.title),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_outline_rounded,
              color: Color(0xFFEF4444), size: 24),
        ),
        confirmDismiss: (_) async {
          widget.onDelete();
          return false; // We handle removal ourselves via provider
        },
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: _hovered
                  ? const Color(0xFF141D2F)
                  : const Color(0xFF0F1624),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: h.doneToday
                    ? color.withOpacity(0.35)
                    : (_hovered
                        ? AppColors.primaryA.withOpacity(0.25)
                        : Colors.white.withOpacity(0.06)),
              ),
              boxShadow: h.doneToday
                  ? [BoxShadow(
                      color: color.withOpacity(0.12),
                      blurRadius: 12, spreadRadius: 1)]
                  : [],
            ),
            child: InkWell(
              onTap: widget.onToggle,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  // Checkbox
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: h.doneToday
                          ? LinearGradient(colors: [color, color.withOpacity(0.7)])
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
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  // Icon
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: color.withOpacity(h.doneToday ? 0.08 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(h.icon,
                        color: h.doneToday
                            ? color.withOpacity(0.4)
                            : color,
                        size: 18),
                  ),
                  const SizedBox(width: 12),
                  // Title + streak
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(h.title,
                            style: TextStyle(
                              color: h.doneToday
                                  ? Colors.grey[600]
                                  : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              decoration: h.doneToday
                                  ? TextDecoration.lineThrough
                                  : null,
                            )),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.local_fire_department,
                              color: Colors.orange, size: 12),
                          const SizedBox(width: 3),
                          Text('${h.streak} day streak',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 11)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(h.category,
                                style: TextStyle(
                                    color: color, fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  // Actions
                  Row(children: [
                    _SmallBtn(
                      icon: Icons.edit_outlined,
                      color: AppColors.primaryA,
                      onTap: widget.onEdit,
                    ),
                    const SizedBox(width: 6),
                    _SmallBtn(
                      icon: Icons.delete_outline_rounded,
                      color: const Color(0xFFEF4444),
                      onTap: widget.onDelete,
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'learning':  return AppColors.primaryA;
      case 'focus':     return const Color(0xFF10B981);
      case 'digital':   return const Color(0xFFEF4444);
      case 'wellness':  return const Color(0xFFF97316);
      case 'fitness':   return const Color(0xFF06B6D4);
      default:          return const Color(0xFFEC4899);
    }
  }
}

class _SmallBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _SmallBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
      );
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryA.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.checklist_rounded,
                  color: AppColors.primaryA, size: 36),
            ),
            const SizedBox(height: 20),
            const Text('No habits yet',
                style: TextStyle(color: Colors.white,
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Add your first habit to start building streaks',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [AppColors.primaryA, AppColors.primaryB]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Add First Habit',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
          ],
        ),
      );
}

// ── Add / Edit habit bottom sheet ────────────────────────────────────────────
class _HabitFormSheet extends StatefulWidget {
  final Habit? existing;
  final void Function(Habit) onSave;

  const _HabitFormSheet({this.existing, required this.onSave});

  @override
  State<_HabitFormSheet> createState() => _HabitFormSheetState();
}

class _HabitFormSheetState extends State<_HabitFormSheet> {
  late TextEditingController _titleCtl;
  String _selectedIcon = 'star';
  String _selectedCategory = 'general';

  static const List<Map<String, dynamic>> _icons = [
    {'name': 'menu_book',  'label': 'Reading'},
    {'name': 'videogame',  'label': 'Games'},
    {'name': 'no_phone',   'label': 'No Phone'},
    {'name': 'fitness',    'label': 'Fitness'},
    {'name': 'water',      'label': 'Water'},
    {'name': 'meditation', 'label': 'Meditate'},
    {'name': 'sleep',      'label': 'Sleep'},
    {'name': 'run',        'label': 'Run'},
    {'name': 'music',      'label': 'Music'},
    {'name': 'journal',    'label': 'Journal'},
    {'name': 'timer',      'label': 'Focus'},
    {'name': 'brain',      'label': 'Learn'},
    {'name': 'food',       'label': 'Nutrition'},
    {'name': 'walk',       'label': 'Walk'},
    {'name': 'sun',        'label': 'Morning'},
    {'name': 'heart',      'label': 'Self-care'},
    {'name': 'star',       'label': 'Other'},
    {'name': 'phone_off',  'label': 'Digital'},
  ];

  static const List<Map<String, dynamic>> _categories = [
    {'value': 'general',  'label': 'General',  'color': Color(0xFFEC4899)},
    {'value': 'focus',    'label': 'Focus',    'color': Color(0xFF10B981)},
    {'value': 'learning', 'label': 'Learning', 'color': Color(0xFF667EEA)},
    {'value': 'digital',  'label': 'Digital',  'color': Color(0xFFEF4444)},
    {'value': 'wellness', 'label': 'Wellness', 'color': Color(0xFFF97316)},
    {'value': 'fitness',  'label': 'Fitness',  'color': Color(0xFF06B6D4)},
  ];

  @override
  void initState() {
    super.initState();
    _titleCtl = TextEditingController(text: widget.existing?.title ?? '');
    _selectedIcon = widget.existing?.iconName ?? 'star';
    _selectedCategory = widget.existing?.category ?? 'general';
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleCtl.text.trim();
    if (title.isEmpty) return;
    widget.onSave(Habit(
      id: widget.existing?.id,
      title: title,
      iconName: _selectedIcon,
      doneToday: widget.existing?.doneToday ?? false,
      streak: widget.existing?.streak ?? 0,
      category: _selectedCategory,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF0F1624),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.existing == null ? 'New Habit' : 'Edit Habit',
              style: const TextStyle(color: Colors.white,
                  fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            // Title input
            TextField(
              controller: _titleCtl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. Morning 10-min reading',
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AppColors.primaryA, width: 1.5),
                ),
                prefixIcon: const Icon(Icons.edit_outlined,
                    color: AppColors.primaryA, size: 18),
              ),
            ),
            const SizedBox(height: 20),
            // Category picker
            const Text('Category',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final selected = _selectedCategory == cat['value'];
                final color = cat['color'] as Color;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat['value'] as String),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? color.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? color : Colors.white.withOpacity(0.1),
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(cat['label'] as String,
                        style: TextStyle(
                          color: selected ? color : Colors.grey[400],
                          fontSize: 12,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        )),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            // Icon picker
            const Text('Icon',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: _icons.length,
              itemBuilder: (_, i) {
                final item = _icons[i];
                final name = item['name'] as String;
                final selected = _selectedIcon == name;
                final icon = Habit.iconForName(name);
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = name),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primaryA.withOpacity(0.2)
                          : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? AppColors.primaryA
                            : Colors.white.withOpacity(0.08),
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Icon(icon,
                        color: selected ? AppColors.primaryA : Colors.grey[500],
                        size: 22),
                  ),
                );
              },
            ),
            const SizedBox(height: 28),
            // Save button
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _save,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppColors.primaryA, AppColors.primaryB]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      widget.existing == null ? 'Add Habit' : 'Save Changes',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
