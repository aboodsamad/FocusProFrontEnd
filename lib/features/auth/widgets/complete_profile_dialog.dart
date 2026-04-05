import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../home/services/user_service.dart';
import '../../home/providers/user_provider.dart';
import 'package:provider/provider.dart';

/// Shows every OAuth login until the user fills in their DOB.
/// Returns true if the profile was saved, false/null if skipped.
Future<bool?> showCompleteProfileDialog(BuildContext context, String token) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false, // force them to explicitly skip
    builder: (_) => _CompleteProfileDialog(token: token),
  );
}

class _CompleteProfileDialog extends StatefulWidget {
  final String token;
  const _CompleteProfileDialog({required this.token});

  @override
  State<_CompleteProfileDialog> createState() => _CompleteProfileDialogState();
}

class _CompleteProfileDialogState extends State<_CompleteProfileDialog> {
  final _nameController = TextEditingController();
  DateTime? _selectedDate;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Pre-fill name from what's already stored
    UserService.getStoredName().then((name) {
      if (name != null && mounted) _nameController.text = name;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 5, now.month, now.day), // must be at least 5 yrs old
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primaryA,
            surface: Color(0xFF0F1624),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() { _selectedDate = picked; _error = null; });
  }

  Future<void> _save() async {
    if (_selectedDate == null) {
      setState(() => _error = 'Please pick your date of birth to continue.');
      return;
    }
    setState(() { _saving = true; _error = null; });

    final dob =
        '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';

    final ok = await UserService.completeProfile(
      token: widget.token,
      dob: dob,
      name: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
    );

    if (!mounted) return;

    if (ok) {
      // Refresh the local profile cache so UserProvider shows the new name/dob
      await UserService.fetchAndSaveProfile(widget.token);
      if (mounted) {
        await context.read<UserProvider>().reloadAfterLogin();
      }
      if (mounted) Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dobLabel = _selectedDate == null
        ? 'Tap to select your birthday'
        : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}';

    return Dialog(
      backgroundColor: const Color(0xFF0F1624),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [AppColors.primaryA, AppColors.primaryB]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_outline, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Complete Your Profile',
                      style: TextStyle(color: Colors.white, fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text('Takes 10 seconds',
                      style: TextStyle(color: AppColors.primaryA, fontSize: 12)),
                ]),
              ),
            ]),

            const SizedBox(height: 8),
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),

            // ── Explanation ──────────────────────────────────────
            Text(
              'Google didn\'t share your full info. A few quick details help us personalise your focus plan.',
              style: TextStyle(color: Colors.grey[400], fontSize: 13, height: 1.5),
            ),

            const SizedBox(height: 20),

            // ── Name field ───────────────────────────────────────
            const Text('Display Name',
                style: TextStyle(color: Colors.white70, fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'How should we call you?',
                hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primaryA, width: 1.5)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),

            const SizedBox(height: 16),

            // ── Date of birth picker ─────────────────────────────
            const Text('Date of Birth',
                style: TextStyle(color: Colors.white70, fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _pickDate,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedDate != null
                        ? AppColors.primaryA.withOpacity(0.7)
                        : Colors.white.withOpacity(0.08),
                    width: _selectedDate != null ? 1.5 : 1.0,
                  ),
                ),
                child: Row(children: [
                  Icon(Icons.cake_outlined,
                      color: _selectedDate != null
                          ? AppColors.primaryA
                          : Colors.grey[600],
                      size: 18),
                  const SizedBox(width: 10),
                  Text(dobLabel,
                      style: TextStyle(
                        color: _selectedDate != null ? Colors.white : Colors.grey[600],
                        fontSize: 13,
                      )),
                ]),
              ),
            ),

            // ── Error message ────────────────────────────────────
            if (_error != null) ...[
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 14),
                const SizedBox(width: 6),
                Text(_error!,
                    style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
              ]),
            ],

            const SizedBox(height: 24),

            // ── Save button ──────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [AppColors.primaryA, AppColors.primaryB]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Save & Continue',
                          style: TextStyle(color: Colors.white,
                              fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ── Skip button ──────────────────────────────────────
            Center(
              child: TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                child: Text("I'll do this later",
                    style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
