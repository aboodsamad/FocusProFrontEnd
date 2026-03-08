import 'package:flutter/material.dart';

/// Bottom-sheet content showing the full FocusScore formula breakdown.
/// Extracted from `_scoreBreakdownSheet` and `_breakdownRow` in [HomeScreen].
class ScoreBreakdownSheet extends StatelessWidget {
  final Map<String, double> components;

  const ScoreBreakdownSheet({super.key, required this.components});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FocusScore Breakdown',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 10),
          _breakdownRow('Test (T)',   components['T'] ?? 0, 0.40),
          _breakdownRow('Games (G)',  components['G'] ?? 0, 0.30),
          _breakdownRow('Screen (S)', components['S'] ?? 0, 0.20),
          _breakdownRow('Habits (H)', components['H'] ?? 0, 0.10),
          const SizedBox(height: 12),
          Text(
            'Formula: 0.40*T + 0.30*G + 0.20*S + 0.10*H',
            style: TextStyle(color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _breakdownRow(String label, double value, double weight) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(label)),
          Expanded(
            flex: 2,
            child: Text(value.toStringAsFixed(0), textAlign: TextAlign.right),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              (value * weight).toStringAsFixed(1),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
