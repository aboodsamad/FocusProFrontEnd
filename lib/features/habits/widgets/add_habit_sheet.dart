import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../models/habit.dart';

/// Deep-Focus-style "New / Edit Habit" bottom sheet.
///
/// Call via [showModalBottomSheet] with [isScrollControlled: true] and
/// [backgroundColor: Colors.transparent].
class AddHabitSheet extends StatefulWidget {
  final Habit? existing;
  final void Function(Habit) onSave;

  const AddHabitSheet({Key? key, this.existing, required this.onSave})
      : super(key: key);

  @override
  State<AddHabitSheet> createState() => _AddHabitSheetState();
}

class _AddHabitSheetState extends State<AddHabitSheet> {
  late TextEditingController _titleCtl;
  late TextEditingController _descCtl;
  late TextEditingController _durationCtl;

  String _selectedIcon = 'star';
  String _selectedCategory = 'general';
  String _frequency = 'Daily'; // 'Daily' | 'Weekly'
  bool _reminderOn = true;
  late List<bool> _days; // [Mon … Sun]

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  // Icon options shown in the sheet (name → IconData)
  static const List<Map<String, dynamic>> _iconOptions = [
    {'name': 'meditation', 'icon': Icons.self_improvement_outlined},
    {'name': 'water',      'icon': Icons.water_drop_outlined},
    {'name': 'fitness',    'icon': Icons.fitness_center_outlined},
    {'name': 'menu_book',  'icon': Icons.menu_book_outlined},
    {'name': 'sleep',      'icon': Icons.bedtime_outlined},
    {'name': 'run',        'icon': Icons.directions_run_outlined},
    {'name': 'timer',      'icon': Icons.timer_outlined},
    {'name': 'brain',      'icon': Icons.psychology_outlined},
    {'name': 'journal',    'icon': Icons.edit_note_outlined},
    {'name': 'sun',        'icon': Icons.wb_sunny_outlined},
    {'name': 'heart',      'icon': Icons.favorite_outline},
    {'name': 'star',       'icon': Icons.star_outline},
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
    final e = widget.existing;
    _titleCtl    = TextEditingController(text: e?.title ?? '');
    _descCtl     = TextEditingController(text: e?.description ?? '');
    _durationCtl = TextEditingController(text: '${e?.durationMinutes ?? 10}');
    _selectedIcon     = e?.iconName ?? 'star';
    _selectedCategory = e?.category ?? 'general';
    _days = e != null
        ? List<bool>.from(e.days)
        : [true, true, true, true, true, false, false];
    // Derive frequency label from days
    _frequency = (_days.every((d) => d) || _days.where((d) => d).length >= 5)
        ? 'Daily'
        : 'Weekly';
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _descCtl.dispose();
    _durationCtl.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleCtl.text.trim();
    if (title.isEmpty) return;
    final duration = int.tryParse(_durationCtl.text.trim()) ?? 10;
    final activeCount = _days.where((d) => d).length;

    widget.onSave(Habit(
      id: widget.existing?.id,
      title: title,
      description: _descCtl.text.trim().isEmpty ? null : _descCtl.text.trim(),
      durationMinutes: duration.clamp(1, 480),
      frequencyPerWeek: activeCount,
      monday:    _days[0],
      tuesday:   _days[1],
      wednesday: _days[2],
      thursday:  _days[3],
      friday:    _days[4],
      saturday:  _days[5],
      sunday:    _days[6],
      doneToday: widget.existing?.doneToday ?? false,
      streak:    widget.existing?.streak ?? 0,
      iconName:  _selectedIcon,
      category:  _selectedCategory,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ─────────────────────────────────────────────────
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Title bar ────────────────────────────────────────────────────
            Row(
              children: [
                Text(
                  widget.existing == null ? 'New Habit' : 'Edit Habit',
                  style: const TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        color: AppColors.onSurfaceVariant, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Habit Name ───────────────────────────────────────────────────
            _label('Habit Name'),
            const SizedBox(height: 8),
            TextField(
              controller: _titleCtl,
              autofocus: true,
              style: const TextStyle(color: AppColors.onSurface, fontSize: 15),
              decoration: _inputDeco(hint: 'e.g. Morning meditation'),
            ),
            const SizedBox(height: 16),

            // ── Description ──────────────────────────────────────────────────
            _label('Description (optional)'),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtl,
              style: const TextStyle(color: AppColors.onSurface, fontSize: 15),
              maxLines: 2,
              decoration: _inputDeco(hint: 'What is this habit about?'),
            ),
            const SizedBox(height: 16),

            // ── Duration ────────────────────────────────────────────────────
            _label('Duration (minutes)'),
            const SizedBox(height: 8),
            SizedBox(
              width: 120,
              child: TextField(
                controller: _durationCtl,
                style: const TextStyle(color: AppColors.onSurface, fontSize: 15),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _inputDeco(hint: '10'),
              ),
            ),
            const SizedBox(height: 20),

            // ── Frequency toggle ─────────────────────────────────────────────
            _label('Frequency'),
            const SizedBox(height: 10),
            _FrequencyToggle(
              selected: _frequency,
              onChanged: (v) {
                setState(() {
                  _frequency = v;
                  if (v == 'Daily') {
                    _days = [true, true, true, true, true, true, true];
                  } else {
                    _days = [true, true, true, true, true, false, false];
                  }
                });
              },
            ),
            const SizedBox(height: 20),

            // ── Days of week ─────────────────────────────────────────────────
            _label('Days of the Week'),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final active = _days[i];
                return GestureDetector(
                  onTap: () => setState(() => _days[i] = !active),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active
                          ? AppColors.primary
                          : AppColors.surfaceContainerLow,
                      border: active
                          ? null
                          : Border.all(
                              color: AppColors.outlineVariant, width: 1),
                    ),
                    child: Center(
                      child: Text(
                        _dayLabels[i].substring(0, 1),
                        style: TextStyle(
                          color: active
                              ? Colors.white
                              : AppColors.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),

            // ── Category ─────────────────────────────────────────────────────
            _label('Category'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final selected = _selectedCategory == cat['value'];
                final color    = cat['color'] as Color;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedCategory = cat['value'] as String),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? color.withOpacity(0.12)
                          : AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? color : AppColors.outlineVariant,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      cat['label'] as String,
                      style: TextStyle(
                        color: selected ? color : AppColors.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // ── Category Icon ────────────────────────────────────────────────
            _label('Category Icon'),
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _iconOptions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final item     = _iconOptions[i];
                  final name     = item['name'] as String;
                  final iconData = item['icon'] as IconData;
                  final selected = _selectedIcon == name;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = name),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: selected
                            ? null
                            : Border.all(
                                color: AppColors.outlineVariant, width: 1),
                      ),
                      child: Icon(
                        iconData,
                        color: selected
                            ? Colors.white
                            : AppColors.onSurfaceVariant,
                        size: 22,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // ── Reminder row ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryContainer.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.access_time_rounded,
                        color: AppColors.secondary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Reminder',
                          style: TextStyle(
                              color: AppColors.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                      Text(
                        _reminderOn ? 'Daily at 08:30 AM' : 'Off',
                        style: const TextStyle(
                            color: AppColors.onSurfaceVariant, fontSize: 12),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Switch(
                    value: _reminderOn,
                    onChanged: (v) => setState(() => _reminderOn = v),
                    activeColor: AppColors.secondary,
                    activeTrackColor: AppColors.secondaryContainer,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Save Habit button ────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
                child: Text(
                  widget.existing == null ? 'Save Habit' : 'Save Changes',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          color: AppColors.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      );

  InputDecoration _inputDeco({required String hint}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.onSurfaceVariant),
        filled: true,
        fillColor: AppColors.surfaceContainerHigh,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.secondary, width: 1.5),
        ),
      );
}

// ── Frequency toggle ───────────────────────────────────────────────────────────
class _FrequencyToggle extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _FrequencyToggle(
      {required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: ['Daily', 'Weekly'].map((label) {
          final active = selected == label;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.surfaceContainerLowest
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: active
                          ? AppColors.primary
                          : AppColors.onSurfaceVariant,
                      fontWeight: active
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
