import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../home/providers/user_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // ── Focus defaults ─────────────────────────────────────────────────────────
  final _durationCtrl = TextEditingController(text: '60');
  final _prepCtrl     = TextEditingController(text: '5');

  // ── Notifications ──────────────────────────────────────────────────────────
  bool _notifySchedule = true;
  bool _notifyHabits   = true;

  // ── Privacy ────────────────────────────────────────────────────────────────
  bool _analyticsConsent = true;

  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _durationCtrl.text = (prefs.getInt('default_duration') ?? 60).toString();
      _prepCtrl.text     = (prefs.getInt('default_prep')     ?? 5).toString();
      _notifySchedule    = prefs.getBool('notify_schedule') ?? true;
      _notifyHabits      = prefs.getBool('notify_habits')   ?? true;
      _analyticsConsent  = prefs.getBool('analytics_consent') ?? true;
    });
  }

  Future<void> _savePrefs() async {
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('default_duration', int.tryParse(_durationCtrl.text) ?? 60);
    await prefs.setInt('default_prep',     int.tryParse(_prepCtrl.text)     ?? 5);
    await prefs.setBool('notify_schedule', _notifySchedule);
    await prefs.setBool('notify_habits',   _notifyHabits);
    await prefs.setBool('analytics_consent', _analyticsConsent);
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved'),
          backgroundColor: AppColors.secondary,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text('Delete Account',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'This will permanently delete your account and all your data. '
          'This action cannot be undone.',
          style: TextStyle(color: Color(0xFF9CA3AF)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF9CA3AF))),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete',
                style: TextStyle(
                    color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      final token = await AuthService.getToken();
      if (token != null) {
        await http.delete(
          Uri.parse('${AuthService.baseUrl}/user/account'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 10));
      }
    } catch (_) {}

    // Clear local data regardless of server response
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      // Pop all routes back to login
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
    }
  }

  @override
  void dispose() {
    _durationCtrl.dispose();
    _prepCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.primary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _savePrefs,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: AppColors.secondary, strokeWidth: 2))
                : const Text('Save',
                    style: TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // ── Focus Defaults ─────────────────────────────────────────────────
          _SectionHeader(icon: Icons.timer_outlined, label: 'Focus Defaults'),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              _MinutesRow(
                label: 'Default duration',
                subtitle: 'Minutes per focus session',
                controller: _durationCtrl,
                min: 5,
                max: 480,
              ),
              _Divider(),
              _MinutesRow(
                label: 'Default prep time',
                subtitle: 'Minutes to prepare before session',
                controller: _prepCtrl,
                min: 1,
                max: 60,
              ),
            ],
          ),

          const SizedBox(height: 28),

          // ── Notifications ──────────────────────────────────────────────────
          _SectionHeader(icon: Icons.notifications_outlined, label: 'Notifications'),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              _ToggleRow(
                label: 'Schedule reminders',
                subtitle: 'Remind me before a scheduled session',
                value: _notifySchedule,
                onChanged: (v) => setState(() => _notifySchedule = v),
              ),
              _Divider(),
              _ToggleRow(
                label: 'Habit reminders',
                subtitle: 'Daily nudge for uncompleted habits',
                value: _notifyHabits,
                onChanged: (v) => setState(() => _notifyHabits = v),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // ── Privacy & Data ─────────────────────────────────────────────────
          _SectionHeader(icon: Icons.shield_outlined, label: 'Privacy & Data'),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              _ToggleRow(
                label: 'Usage analytics',
                subtitle: 'Help improve FocusPro with anonymous data',
                value: _analyticsConsent,
                onChanged: (v) => setState(() => _analyticsConsent = v),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // ── Danger Zone ────────────────────────────────────────────────────
          _SectionHeader(
              icon: Icons.warning_amber_rounded,
              label: 'Danger Zone',
              iconColor: AppColors.error),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _deleting ? null : _deleteAccount,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.delete_forever_rounded,
                      color: AppColors.error, size: 22),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delete Account',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Permanently delete your account and all data',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_deleting)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: AppColors.error, strokeWidth: 2),
                    )
                  else
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.error, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Header ─────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor;

  const _SectionHeader({
    required this.icon,
    required this.label,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppColors.secondary;
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ── Settings Card ──────────────────────────────────────────────────────────────
class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF374151)),
      ),
      child: Column(children: children),
    );
  }
}

// ── Toggle Row ─────────────────────────────────────────────────────────────────
class _ToggleRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        color: Color(0xFF9CA3AF), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.secondary,
            inactiveThumbColor: const Color(0xFF6B7280),
            inactiveTrackColor: const Color(0xFF374151),
          ),
        ],
      ),
    );
  }
}

// ── Minutes Row ────────────────────────────────────────────────────────────────
class _MinutesRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final TextEditingController controller;
  final int min;
  final int max;

  const _MinutesRow({
    required this.label,
    required this.subtitle,
    required this.controller,
    this.min = 1,
    this.max = 480,
  });

  void _adjust(int delta) {
    final cur = int.tryParse(controller.text) ?? min;
    final next = (cur + delta).clamp(min, max);
    controller.text = next.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        color: Color(0xFF9CA3AF), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Stepper
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => _adjust(-5),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF374151),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.remove, color: Colors.white, size: 16),
                ),
              ),
              SizedBox(
                width: 58,
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 6),
                    suffix: Text('m',
                        style: TextStyle(
                            color: Color(0xFF9CA3AF), fontSize: 12)),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _adjust(5),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add,
                      color: AppColors.secondary, size: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Divider ────────────────────────────────────────────────────────────────────
class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: const Color(0xFF374151),
    );
  }
}
