import 'package:flutter/material.dart';

/// Score: 0=empty, 1=weak(red/block), 2=fair(orange/allow), 3=good(orange/allow), 4=strong(green/allow)
int passwordStrengthScore(String password) {
  if (password.isEmpty) return 0;
  if (password.length < 8) return 1;
  int score = 1; // length criterion satisfied
  if (password.contains(RegExp(r'[A-Z]'))) score++;
  if (password.contains(RegExp(r'[0-9]'))) score++;
  if (password.contains(RegExp(r'[^a-zA-Z0-9]'))) score++;
  return score;
}

/// Returns true when password is fair or better (orange or green).
bool passwordIsAllowed(String password) => passwordStrengthScore(password) >= 2;

class PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const PasswordStrengthIndicator({super.key, required this.password});

  static Color _strengthColor(int score) {
    if (score <= 1) return const Color(0xFFE53935);
    if (score <= 3) return const Color(0xFFFB8C00);
    return const Color(0xFF43A047);
  }

  static String _strengthLabel(int score) {
    if (score <= 1) return 'Weak — not allowed';
    if (score == 2) return 'Fair';
    if (score == 3) return 'Good';
    return 'Strong';
  }

  static List<String> _missingCriteria(String password) {
    final criteria = <String>[];
    if (password.length < 8) criteria.add('8+ characters');
    if (!password.contains(RegExp(r'[A-Z]'))) criteria.add('uppercase letter');
    if (!password.contains(RegExp(r'[0-9]'))) criteria.add('a number');
    if (!password.contains(RegExp(r'[^a-zA-Z0-9]'))) {
      criteria.add('special character (!@#...)');
    }
    return criteria;
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    final score = passwordStrengthScore(password);
    final color = _strengthColor(score);
    final label = _strengthLabel(score);
    final missing = _missingCriteria(password);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 4.0,
            backgroundColor: const Color(0xFFE0E0E0),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(
              score >= 4
                  ? Icons.check_circle_rounded
                  : score >= 2
                      ? Icons.info_outline_rounded
                      : Icons.warning_amber_rounded,
              color: color,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (missing.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            'Must include: ${missing.join(' · ')}',
            style: const TextStyle(
              color: Color(0xFF757575),
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }
}
