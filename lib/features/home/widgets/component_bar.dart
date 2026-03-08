import 'package:flutter/material.dart';

/// Single labelled progress bar for one focus-score component (T / G / S / H).
/// Extracted from `_componentBar` in [HomeScreen].
/// Must be placed inside a [Row] since it wraps itself in [Expanded].
class ComponentBar extends StatelessWidget {
  final String label;
  final double value;
  final Color primaryA;
  final Color primaryB;

  const ComponentBar({
    super.key,
    required this.label,
    required this.value,
    required this.primaryA,
    required this.primaryB,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          const SizedBox(height: 6),
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              Container(
                height: 8,
                width: (value / 100) *
                    MediaQuery.of(context).size.width *
                    0.18,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [primaryA, primaryB]),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value.toStringAsFixed(0),
            style: TextStyle(fontSize: 12, color: Colors.grey[800]),
          ),
        ],
      ),
    );
  }
}
