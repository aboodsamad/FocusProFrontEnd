import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/focus_schedule_model.dart';
import '../services/lock_in_service.dart';
import '../services/android_lockin_helper.dart';

class SchedulesPage extends StatefulWidget {
  const SchedulesPage({super.key});

  @override
  State<SchedulesPage> createState() => _SchedulesPageState();
}

class _SchedulesPageState extends State<SchedulesPage> {
  static const _dark = Color(0xFF080D1A);

  List<FocusScheduleModel> _schedules = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await LockInService.getSchedules();
    if (mounted) setState(() { _schedules = list; _loading = false; });
  }

  Future<void> _toggle(FocusScheduleModel s) async {
    try {
      final updated = await LockInService.toggleSchedule(s.id);
      if (updated.isActive) {
        await AndroidLockInHelper.scheduleAlarm(updated.scheduledTime, updated.id);
      } else {
        await AndroidLockInHelper.cancelAlarm(s.id);
      }
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update schedule.')));
      }
    }
  }

  Future<void> _delete(FocusScheduleModel s) async {
    try {
      await LockInService.deleteSchedule(s.id);
      await AndroidLockInHelper.cancelAlarm(s.id);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete schedule.')));
      }
    }
  }

  void _openCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CreateScheduleSheet(
        onCreated: (schedule) async {
          await AndroidLockInHelper.scheduleAlarm(
              schedule.scheduledTime, schedule.id);
          await _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dark,
      appBar: AppBar(
        backgroundColor: _dark,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Focus Schedules',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateSheet,
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.secondary))
          : _schedules.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.alarm_off_rounded,
                          color: const Color(0xFF374151), size: 48),
                      const SizedBox(height: 12),
                      const Text('No schedules yet',
                          style: TextStyle(
                              color: Color(0xFF9CA3AF), fontSize: 15)),
                      const SizedBox(height: 6),
                      const Text('Tap + to create your first schedule',
                          style: TextStyle(
                              color: Color(0xFF6B7280), fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: _schedules.length,
                  itemBuilder: (_, i) => _buildCard(_schedules[i]),
                ),
    );
  }

  Widget _buildCard(FocusScheduleModel s) {
    final isWakeup = s.scheduleType == 'WAKEUP';
    final typeColor =
        isWakeup ? AppColors.secondary : AppColors.onTertiaryContainer;
    final days = s.daysOfWeek?.isNotEmpty == true ? s.daysOfWeek! : 'Every day';

    return Dismissible(
      key: ValueKey(s.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: AppColors.error, size: 24),
      ),
      onDismissed: (_) => _delete(s),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: s.isActive
                ? AppColors.secondary.withValues(alpha: 0.3)
                : const Color(0xFF1F2937),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: typeColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                isWakeup ? 'WAKE-UP' : 'FOCUS',
                style: TextStyle(
                    color: typeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.scheduledTime,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${s.durationMinutes}m focus · ${s.prepTimerMinutes}m prep · $days',
                    style: const TextStyle(
                        color: Color(0xFF9CA3AF), fontSize: 12),
                  ),
                ],
              ),
            ),
            Switch(
              value: s.isActive,
              onChanged: (_) => _toggle(s),
              activeColor: AppColors.secondary,
              inactiveThumbColor: const Color(0xFF6B7280),
              inactiveTrackColor: const Color(0xFF374151),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Create Schedule Bottom Sheet ───────────────────────────────────────────

class _CreateScheduleSheet extends StatefulWidget {
  final Future<void> Function(FocusScheduleModel) onCreated;

  const _CreateScheduleSheet({required this.onCreated});

  @override
  State<_CreateScheduleSheet> createState() => _CreateScheduleSheetState();
}

class _CreateScheduleSheetState extends State<_CreateScheduleSheet> {
  String _type = 'WAKEUP';
  TimeOfDay _time = const TimeOfDay(hour: 7, minute: 0);
  int _duration = 60;
  int _prep = 5;
  bool _repeat = true;
  final Set<String> _days = {'MON', 'TUE', 'WED', 'THU', 'FRI'};
  bool _saving = false;

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _dayKeys = [
    'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'
  ];

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final timeStr =
          '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';
      final daysOfWeek = _repeat && _days.isNotEmpty
          ? _dayKeys.where(_days.contains).join(',')
          : null;

      final schedule = await LockInService.createSchedule(
        scheduleType: _type,
        scheduledTime: timeStr,
        durationMinutes: _duration,
        prepTimerMinutes: _prep,
        isRecurring: _repeat,
        daysOfWeek: daysOfWeek,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      await widget.onCreated(schedule);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save schedule.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF374151),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('New Focus Schedule',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // Type selector
            const Text('Type',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
            const SizedBox(height: 8),
            Row(children: [
              _TypeChip(
                label: 'Wake-Up',
                selected: _type == 'WAKEUP',
                onTap: () => setState(() => _type = 'WAKEUP'),
              ),
              const SizedBox(width: 8),
              _TypeChip(
                label: 'Focus Block',
                selected: _type == 'FOCUS_BLOCK',
                onTap: () => setState(() => _type = 'FOCUS_BLOCK'),
              ),
            ]),
            const SizedBox(height: 20),

            // Time picker
            const Text('Time',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _time,
                  builder: (c, child) => Theme(
                    data: Theme.of(c).copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: AppColors.secondary,
                        onSurface: Colors.white,
                        surface: Color(0xFF1F2937),
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) setState(() => _time = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2937),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.secondary.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.access_time_rounded,
                      color: AppColors.secondary, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    _time.format(context),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  const Icon(Icons.edit_outlined,
                      color: Color(0xFF6B7280), size: 16),
                ]),
              ),
            ),
            const SizedBox(height: 20),

            // Duration
            _SheetSelectorRow(
              label: 'Focus duration',
              options: const [30, 60, 90, 120],
              selected: _duration,
              labelFn: (v) => v == 60
                  ? '1hr'
                  : v == 90
                      ? '1.5hr'
                      : v == 120
                          ? '2hr'
                          : '${v}m',
              onSelect: (v) => setState(() => _duration = v),
            ),
            const SizedBox(height: 16),

            // Prep timer
            _SheetSelectorRow(
              label: 'Prep timer',
              options: const [5, 10, 15],
              selected: _prep,
              labelFn: (v) => '${v}m',
              onSelect: (v) => setState(() => _prep = v),
            ),
            const SizedBox(height: 20),

            // Repeat daily toggle
            Row(children: [
              const Text('Repeat daily',
                  style: TextStyle(color: Colors.white, fontSize: 15)),
              const Spacer(),
              Switch(
                value: _repeat,
                onChanged: (v) => setState(() => _repeat = v),
                activeColor: AppColors.secondary,
                inactiveThumbColor: const Color(0xFF6B7280),
                inactiveTrackColor: const Color(0xFF374151),
              ),
            ]),

            // Day-of-week checkboxes
            if (_repeat) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (i) {
                  final key = _dayKeys[i];
                  final selected = _days.contains(key);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (selected) {
                        _days.remove(key);
                      } else {
                        _days.add(key);
                      }
                    }),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.secondary.withValues(alpha: 0.2)
                            : const Color(0xFF1F2937),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? AppColors.secondary
                              : const Color(0xFF374151),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _dayLabels[i],
                          style: TextStyle(
                            color: selected
                                ? AppColors.secondary
                                : const Color(0xFF9CA3AF),
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
            const SizedBox(height: 24),

            // Save button
            GestureDetector(
              onTap: _saving ? null : _save,
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
                child: Center(
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Save',
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
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.secondary.withValues(alpha: 0.15)
              : const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.secondary : const Color(0xFF374151),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.secondary : const Color(0xFF9CA3AF),
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _SheetSelectorRow extends StatelessWidget {
  final String label;
  final List<int> options;
  final int selected;
  final String Function(int) labelFn;
  final void Function(int) onSelect;

  const _SheetSelectorRow({
    required this.label,
    required this.options,
    required this.selected,
    required this.labelFn,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.secondary.withValues(alpha: 0.2)
                        : const Color(0xFF1F2937),
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
                      color: active
                          ? AppColors.secondary
                          : const Color(0xFF9CA3AF),
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
}
