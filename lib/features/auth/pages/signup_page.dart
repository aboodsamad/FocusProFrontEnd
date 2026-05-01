import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/url_helper.dart';
import './login_page.dart';
import '../../diagnostic/pages/diagnostic_page.dart';
import '../../home/providers/user_provider.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _consentUsage = false;
  DateTime? _selectedDate;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _slideController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _scaleController = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _scaleAnimation = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _scaleController, curve: Curves.easeOut));

    _startAnimations();
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 100));
    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  // ── Date picker ────────────────────────────────────────────────────────────

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dobController.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  // ── Sign up — step 1: send OTP, show sheet ─────────────────────────────────

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your date of birth'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthService.sendOtp(_emailController.text.trim());
      setState(() => _isLoading = false);
      if (!mounted) return;

      final verified = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (_) => _OtpSheet(email: _emailController.text.trim()),
      );

      if (verified == true) await _doRegister();
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Sign up — step 2: register after OTP verified ──────────────────────────

  Future<void> _doRegister() async {
    setState(() => _isLoading = true);

    final signupData = {
      'username': _usernameController.text.trim(),
      'email': _emailController.text.trim(),
      'password': _passwordController.text.trim(),
      'name': _nameController.text.trim(),
      'dob': _dobController.text.trim(),
      'consentUsage': _consentUsage,
    };

    try {
      final result = await AuthService.signup(signupData);
      setState(() => _isLoading = false);

      final token = result['token']?.toString() ?? '';
      if (token.isNotEmpty) {
        await AuthService.saveToken(token);
        NotificationService.init();
        if (mounted) await context.read<UserProvider>().reloadAfterLogin();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Welcome! Let\'s set up your focus profile.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => DiagnosticPage(token: token)),
        );
      } else {
        throw Exception('Signup failed: No token received');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obscure = false,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          readOnly: readOnly,
          onTap: onTap,
          keyboardType: keyboardType,
          style: const TextStyle(color: AppColors.onSurface, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.outline, fontSize: 15),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppColors.surfaceContainerHigh,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.secondary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          validator: validator,
        ),
      ],
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 32,
              bottom: MediaQuery.of(context).viewInsets.bottom + 32,
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // ── App logo & name ──────────────────────────────
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(32),
                          ),
                          child: RichText(
                            text: const TextSpan(
                              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                              children: [
                                TextSpan(text: 'Locked', style: TextStyle(color: Colors.white)),
                                TextSpan(text: 'In', style: TextStyle(color: AppColors.secondaryFixed)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Card ─────────────────────────────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.onSurface.withOpacity(0.06),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(32),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Card heading ─────────────────────────
                                const Text(
                                  'Create Account',
                                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Step into your deep work sanctuary.',
                                  style: TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
                                ),
                                const SizedBox(height: 24),

                                // ── Name ─────────────────────────────────
                                _buildInputField(
                                  controller: _nameController,
                                  label: 'Full Name',
                                  hint: 'Your full name',
                                  validator: (v) => (v == null || v.isEmpty) ? 'Please enter your full name' : null,
                                ),
                                const SizedBox(height: 14),

                                // ── Username ──────────────────────────────
                                _buildInputField(
                                  controller: _usernameController,
                                  label: 'Username',
                                  hint: 'Choose a username',
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Please enter a username';
                                    if (v.length < 3) return 'Username must be at least 3 characters';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),

                                // ── Email ────────────────────────────────
                                _buildInputField(
                                  controller: _emailController,
                                  label: 'Email',
                                  hint: 'your@email.com',
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Please enter your email';
                                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                                      return 'Please enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),

                                // ── Date of Birth ─────────────────────────
                                _buildInputField(
                                  controller: _dobController,
                                  label: 'Date of Birth',
                                  hint: 'YYYY-MM-DD',
                                  readOnly: true,
                                  onTap: () => _selectDate(context),
                                  suffixIcon: const Icon(
                                    Icons.calendar_today_outlined,
                                    color: AppColors.outline,
                                    size: 18,
                                  ),
                                  validator: (v) =>
                                      (v == null || v.isEmpty) ? 'Please select your date of birth' : null,
                                ),
                                const SizedBox(height: 14),

                                // ── Password ──────────────────────────────
                                _buildInputField(
                                  controller: _passwordController,
                                  label: 'Password',
                                  hint: 'At least 6 characters',
                                  obscure: _obscurePassword,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      color: AppColors.outline,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Please enter a password';
                                    if (v.length < 6) return 'Password must be at least 6 characters';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),

                                // ── Confirm Password ──────────────────────
                                _buildInputField(
                                  controller: _confirmPasswordController,
                                  label: 'Confirm Password',
                                  hint: 'Repeat your password',
                                  obscure: _obscureConfirmPassword,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: AppColors.outline,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Please confirm your password';
                                    if (v != _passwordController.text) return 'Passwords do not match';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // ── Consent checkbox ──────────────────────
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Checkbox(
                                        value: _consentUsage,
                                        onChanged: (v) => setState(() => _consentUsage = v ?? false),
                                        activeColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Text(
                                        'I agree to data usage terms',
                                        style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                // ── Create Account button ─────────────────
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _signup,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: AppColors.onPrimary,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.onPrimary),
                                            ),
                                          )
                                        : const Text(
                                            'Create Account',
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // ── Divider ───────────────────────────────
                                Row(
                                  children: [
                                    const Expanded(child: Divider(color: AppColors.outlineVariant, thickness: 1)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Text(
                                        'or continue with',
                                        style: TextStyle(fontSize: 13, color: AppColors.outline),
                                      ),
                                    ),
                                    const Expanded(child: Divider(color: AppColors.outlineVariant, thickness: 1)),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // ── Google button ─────────────────────────
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: OutlinedButton(
                                    onPressed: () {
                                      openUrl('${AuthService.baseUrl}/oauth2/authorization/google');
                                    },
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: AppColors.surfaceContainerLowest,
                                      foregroundColor: AppColors.onSurface,
                                      side: const BorderSide(color: AppColors.outlineVariant, width: 1),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: Image.network(
                                            'https://developers.google.com/identity/images/g-logo.png',
                                            fit: BoxFit.contain,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                width: 18,
                                                height: 18,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF4285F4),
                                                  borderRadius: BorderRadius.circular(2),
                                                ),
                                                child: const Center(
                                                  child: Text(
                                                    'G',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Text(
                                          'Continue with Google',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // ── Log in link ───────────────────────────
                                Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Already have an account? ',
                                        style: TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
                                      ),
                                      GestureDetector(
                                        onTap: () => Navigator.of(context).pushReplacement(
                                          MaterialPageRoute(builder: (_) => const LoginPage()),
                                        ),
                                        child: const Text(
                                          'Log in',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.secondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── OTP bottom sheet ───────────────────────────────────────────────────────────

class _OtpSheet extends StatefulWidget {
  final String email;
  const _OtpSheet({required this.email});

  @override
  State<_OtpSheet> createState() => _OtpSheetState();
}

class _OtpSheetState extends State<_OtpSheet> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  int _secondsLeft = 60;
  Timer? _timer;
  bool _isVerifying = false;
  bool _isSending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNodes[0].requestFocus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_secondsLeft == 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _verify() async {
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length < 6) {
      setState(() => _error = 'Please enter all 6 digits');
      return;
    }
    setState(() { _isVerifying = true; _error = null; });
    try {
      await AuthService.verifyOtp(widget.email, otp);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
      for (final c in _controllers) c.clear();
      _focusNodes[0].requestFocus();
    }
  }

  Future<void> _resend() async {
    setState(() { _isSending = true; _error = null; });
    try {
      await AuthService.sendOtp(widget.email);
      if (!mounted) return;
      for (final c in _controllers) c.clear();
      setState(() { _isSending = false; _secondsLeft = 60; });
      _startTimer();
      _focusNodes[0].requestFocus();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _error = 'Failed to resend. Please try again.';
      });
    }
  }

  Widget _buildDigitBox(int index) {
    return SizedBox(
      width: 44,
      height: 56,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.onSurface,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: AppColors.surfaceContainerHigh,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.secondary, width: 2),
          ),
        ),
        onChanged: (value) {
          if (value.isNotEmpty) {
            if (index < 5) {
              _focusNodes[index + 1].requestFocus();
            } else {
              _focusNodes[index].unfocus();
            }
          } else if (index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottomInset + 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // close button
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: AppColors.outline),
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            const Text(
              'Verify your email',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the 6-digit code sent to\n${widget.email}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 28),
            // digit boxes
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, _buildDigitBox),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.error)),
            ],
            const SizedBox(height: 24),
            // verify button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isVerifying ? null : _verify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                child: _isVerifying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.onPrimary),
                        ),
                      )
                    : const Text('Verify', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 16),
            // countdown / resend
            _secondsLeft > 0
                ? Text(
                    'Resend code in $_secondsLeft s',
                    style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                  )
                : TextButton(
                    onPressed: _isSending ? null : _resend,
                    child: _isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.secondary),
                          )
                        : const Text(
                            'Resend code',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondary,
                            ),
                          ),
                  ),
          ],
        ),
      ),
    );
  }
}
