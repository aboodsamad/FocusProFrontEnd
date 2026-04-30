import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/notification_service.dart';
import '../../home/providers/user_provider.dart';
import '../../home/services/user_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Focus defaults — must match the button sets in lock_in_page.dart
  // duration: [30, 60, 90, 120]   break/prep: [5, 10, 15]
  // Notifications
  bool _notifySchedule = true;
  bool _notifyHabits   = true;

  bool _saving     = false;
  bool _deleting   = false;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _notifySchedule  = p.getBool('notify_schedule') ?? true;
      _notifyHabits    = p.getBool('notify_habits')   ?? true;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final p = await SharedPreferences.getInstance();
    await p.setBool('notify_schedule', _notifySchedule);
    await p.setBool('notify_habits',   _notifyHabits);

    // Wire notification service: stop when both disabled, restart when either enabled
    if (!_notifySchedule && !_notifyHabits) {
      NotificationService.stop();
    } else {
      NotificationService.init();
    }

    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Settings saved',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ── Edit profile ───────────────────────────────────────────────────────────
  Future<void> _editProfile() async {
    final user = context.read<UserProvider>();
    final nameCtrl = TextEditingController(text: user.name == 'User' ? '' : user.name);
    bool saving = false;
    String? error;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Edit Profile',
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _InputField(
                  controller: nameCtrl,
                  label: 'Display Name',
                  hint: 'Enter your name',
                  icon: Icons.person_outline_rounded,
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: saving
                        ? null
                        : () async {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) {
                              setModal(() => error = 'Name cannot be empty');
                              return;
                            }
                            setModal(() { saving = true; error = null; });
                            try {
                              final token = await AuthService.getToken();
                              if (token == null) throw Exception('Not logged in');
                              final resp = await http.put(
                                Uri.parse('${AuthService.baseUrl}/user/update-profile'),
                                headers: {
                                  'Content-Type': 'application/json',
                                  'Authorization': 'Bearer $token',
                                },
                                body: jsonEncode({'name': name}),
                              ).timeout(const Duration(seconds: 10));

                              if (resp.statusCode == 200) {
                                await UserService.fetchAndSaveProfile(token);
                                if (mounted) {
                                  await context.read<UserProvider>().reloadAfterLogin();
                                }
                                if (ctx.mounted) Navigator.pop(ctx);
                              } else {
                                setModal(() {
                                  saving = false;
                                  error = 'Update failed. Please try again.';
                                });
                              }
                            } catch (_) {
                              setModal(() {
                                saving = false;
                                error = 'Network error. Please try again.';
                              });
                            }
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: saving ? AppColors.primary.withOpacity(0.6) : AppColors.primary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: saving
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    nameCtrl.dispose();
  }

  // ── Change password ────────────────────────────────────────────────────────
  Future<void> _changePassword() async {
    final currentCtrl = TextEditingController();
    final newCtrl     = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool saving = false;
    String? error;
    bool obscureCurrent = true;
    bool obscureNew     = true;
    bool obscureConfirm = true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Change Password',
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _InputField(
                  controller: currentCtrl,
                  label: 'Current Password',
                  hint: 'Enter current password',
                  icon: Icons.lock_outline_rounded,
                  obscure: obscureCurrent,
                  onToggleObscure: () => setModal(() => obscureCurrent = !obscureCurrent),
                ),
                const SizedBox(height: 12),
                _InputField(
                  controller: newCtrl,
                  label: 'New Password',
                  hint: 'At least 8 characters',
                  icon: Icons.lock_reset_rounded,
                  obscure: obscureNew,
                  onToggleObscure: () => setModal(() => obscureNew = !obscureNew),
                ),
                const SizedBox(height: 12),
                _InputField(
                  controller: confirmCtrl,
                  label: 'Confirm New Password',
                  hint: 'Repeat new password',
                  icon: Icons.lock_rounded,
                  obscure: obscureConfirm,
                  onToggleObscure: () => setModal(() => obscureConfirm = !obscureConfirm),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: saving
                        ? null
                        : () async {
                            final current = currentCtrl.text;
                            final newPass = newCtrl.text;
                            final confirm = confirmCtrl.text;
                            if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
                              setModal(() => error = 'All fields are required');
                              return;
                            }
                            if (newPass.length < 8) {
                              setModal(() => error = 'New password must be at least 8 characters');
                              return;
                            }
                            if (newPass != confirm) {
                              setModal(() => error = 'Passwords do not match');
                              return;
                            }
                            setModal(() { saving = true; error = null; });
                            try {
                              final token = await AuthService.getToken();
                              if (token == null) throw Exception('Not logged in');
                              final resp = await http.put(
                                Uri.parse('${AuthService.baseUrl}/user/change-password'),
                                headers: {
                                  'Content-Type': 'application/json',
                                  'Authorization': 'Bearer $token',
                                },
                                body: jsonEncode({
                                  'currentPassword': current,
                                  'newPassword': newPass,
                                }),
                              ).timeout(const Duration(seconds: 10));

                              if (resp.statusCode == 200) {
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Password changed successfully',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                      ),
                                      backgroundColor: AppColors.secondary,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  );
                                }
                              } else {
                                String msg = 'Failed. Check your current password.';
                                try {
                                  final body = jsonDecode(resp.body) as Map<String, dynamic>;
                                  if (body['message'] != null) msg = body['message'] as String;
                                } catch (_) {}
                                setModal(() { saving = false; error = msg; });
                              }
                            } catch (_) {
                              setModal(() {
                                saving = false;
                                error = 'Network error. Please try again.';
                              });
                            }
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: saving ? AppColors.primary.withOpacity(0.6) : AppColors.primary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: saving
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Update Password',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    currentCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();
  }

  // ── Sign out ───────────────────────────────────────────────────────────────
  Future<void> _signOut() async {
    final ok = await _confirmDialog(
      icon: Icons.logout_rounded,
      iconColor: AppColors.primary,
      iconBg: AppColors.primaryContainer.withOpacity(0.15),
      title: 'Sign Out',
      body: 'You\'ll need to log in again to access your account.',
      confirmLabel: 'Sign Out',
      confirmColor: AppColors.primary,
    );
    if (ok != true || !mounted) return;

    setState(() => _signingOut = true);
    NotificationService.stop();
    await AuthService.logout();
    if (mounted) {
      await context.read<UserProvider>().logout();
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    }
  }

  // ── Delete account ─────────────────────────────────────────────────────────
  Future<void> _confirmDelete() async {
    final ok = await _confirmDialog(
      icon: Icons.delete_forever_rounded,
      iconColor: AppColors.error,
      iconBg: AppColors.error.withOpacity(0.12),
      title: 'Delete Account',
      body: 'All your progress, habits, and data will be permanently deleted. This cannot be undone.',
      confirmLabel: 'Delete',
      confirmColor: AppColors.error,
    );
    if (ok != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      final token = await AuthService.getToken();
      if (token != null) {
        await http
            .delete(
              Uri.parse('${AuthService.baseUrl}/user/account'),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(const Duration(seconds: 10));
      }
    } catch (_) {}
    final p = await SharedPreferences.getInstance();
    await p.clear();
    NotificationService.stop();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    }
  }

  // ── Generic confirm dialog ─────────────────────────────────────────────────
  Future<bool?> _confirmDialog({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String body,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.onSurfaceVariant, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.outlineVariant),
                        ),
                        child: const Center(
                          child: Text('Cancel',
                            style: TextStyle(
                              color: AppColors.onSurface, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: confirmColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            confirmLabel,
                            style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // watch so the account card re-renders after profile edits
    final user = context.watch<UserProvider>();
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                children: [
                  _buildAccountCard(user),
                  const SizedBox(height: 24),
                  _buildSecurity(),
                  const SizedBox(height: 24),
                  _buildNotifications(),
                  const SizedBox(height: 32),
                  _buildSignOut(),
                  const SizedBox(height: 16),
                  _buildDangerZone(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: const Icon(Icons.arrow_back_ios_rounded,
                  color: AppColors.onSurface, size: 18),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Settings',
            style: TextStyle(
              color: AppColors.onSurface, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _saving ? null : _save,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
              child: _saving
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text(
                      'Save',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section label ──────────────────────────────────────────────────────────
  Widget _sectionLabel(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.secondary, size: 15),
          const SizedBox(width: 8),
          Text(
            text.toUpperCase(),
            style: const TextStyle(
              color: AppColors.secondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  // ── Card shell ─────────────────────────────────────────────────────────────
  Widget _card(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1)
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: AppColors.outlineVariant.withOpacity(0.5),
              ),
          ],
        ],
      ),
    );
  }

  // ── Account card ───────────────────────────────────────────────────────────
  Widget _buildAccountCard(UserProvider user) {
    final initial = user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Account', Icons.person_outline_rounded),
        _card([
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: AppColors.onPrimaryContainer,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${user.username}',
                        style: const TextStyle(
                          color: AppColors.secondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        style: const TextStyle(
                          color: AppColors.onSurfaceVariant, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Edit profile button
                GestureDetector(
                  onTap: _editProfile,
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.secondary.withOpacity(0.25)),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      color: AppColors.secondary,
                      size: 17,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ],
    );
  }

  // ── Security ───────────────────────────────────────────────────────────────
  Widget _buildSecurity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Security', Icons.shield_outlined),
        _card([
          _actionRow(
            icon: Icons.lock_outline_rounded,
            label: 'Change Password',
            subtitle: 'Update your account password',
            onTap: _changePassword,
          ),
        ]),
      ],
    );
  }

  // ── Notifications ──────────────────────────────────────────────────────────
  Widget _buildNotifications() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Notifications', Icons.notifications_outlined),
        _card([
          _toggleRow(
            icon: Icons.schedule_rounded,
            label: 'Session reminders',
            subtitle: 'Remind me before a focus session starts',
            value: _notifySchedule,
            onChanged: (v) {
              setState(() => _notifySchedule = v);
              if (!v && !_notifyHabits) {
                NotificationService.stop();
              } else if (v) {
                NotificationService.init();
              }
            },
          ),
          _toggleRow(
            icon: Icons.check_circle_outline_rounded,
            label: 'Habit reminders',
            subtitle: 'Daily nudge for habits not yet completed',
            value: _notifyHabits,
            onChanged: (v) {
              setState(() => _notifyHabits = v);
              if (!v && !_notifySchedule) {
                NotificationService.stop();
              } else if (v) {
                NotificationService.init();
              }
            },
          ),
        ]),
      ],
    );
  }

  // ── Sign out ───────────────────────────────────────────────────────────────
  Widget _buildSignOut() {
    return GestureDetector(
      onTap: _signingOut ? null : _signOut,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.logout_rounded,
                  color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sign Out',
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    )),
                  SizedBox(height: 3),
                  Text('Log out of your account',
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
            _signingOut
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2))
                : const Icon(Icons.chevron_right_rounded,
                    color: AppColors.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }

  // ── Danger Zone ────────────────────────────────────────────────────────────
  Widget _buildDangerZone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Danger Zone', Icons.warning_amber_rounded),
        GestureDetector(
          onTap: _deleting ? null : _confirmDelete,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.error.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete_forever_rounded,
                      color: AppColors.error, size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Delete My Account',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        )),
                      SizedBox(height: 3),
                      Text('Permanently remove all your data',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        )),
                    ],
                  ),
                ),
                _deleting
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: AppColors.error, strokeWidth: 2))
                    : const Icon(Icons.chevron_right_rounded,
                        color: AppColors.error, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Reusable: action row (chevron, navigates somewhere) ───────────────────
  Widget _actionRow({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.secondary, size: 19),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    )),
                  const SizedBox(height: 2),
                  Text(subtitle,
                    style: const TextStyle(
                      color: AppColors.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }

  // ── Reusable: toggle row ───────────────────────────────────────────────────
  Widget _toggleRow({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.secondary, size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                  style: const TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  )),
                const SizedBox(height: 2),
                Text(subtitle,
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.secondary,
            inactiveThumbColor: AppColors.onSurfaceVariant,
            inactiveTrackColor: AppColors.surfaceContainerHigh,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  // ── Reusable: stepper row ──────────────────────────────────────────────────
  Widget _stepperRow({
    required IconData icon,
    required String label,
    required String subtitle,
    required int value,
    required String unit,
    required int step,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.secondary, size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                  style: const TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  )),
                const SizedBox(height: 2),
                Text(subtitle,
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => onChanged((value - step).clamp(min, max)),
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: const Icon(Icons.remove, color: AppColors.onSurface, size: 17),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 52,
            child: Text(
              '$value $unit',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.secondary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => onChanged((value + step).clamp(min, max)),
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
              ),
              child: const Icon(Icons.add, color: AppColors.secondary, size: 17),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared input field widget ──────────────────────────────────────────────────
class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final VoidCallback? onToggleObscure;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.onToggleObscure,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: const TextStyle(color: AppColors.onSurface, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14),
            prefixIcon: Icon(icon, color: AppColors.secondary, size: 18),
            suffixIcon: onToggleObscure != null
                ? GestureDetector(
                    onTap: onToggleObscure,
                    child: Icon(
                      obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: AppColors.onSurfaceVariant,
                      size: 18,
                    ),
                  )
                : null,
            filled: true,
            fillColor: AppColors.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.secondary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }
}
