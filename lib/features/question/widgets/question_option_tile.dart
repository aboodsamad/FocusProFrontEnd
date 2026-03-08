import 'package:flutter/material.dart';

/// Single selectable option card for [QuestionPage].
/// Highlighted with a gradient when [isSelected] is true.
class QuestionOptionTile extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;
  final Color primaryA;
  final Color primaryB;

  const QuestionOptionTile({
    super.key,
    required this.text,
    required this.isSelected,
    required this.onTap,
    required this.primaryA,
    required this.primaryB,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 4 : 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: isSelected
                ? LinearGradient(colors: [primaryA, primaryB])
                : null,
            color: isSelected ? null : Colors.white,
            border: Border.all(
              color: isSelected ? Colors.transparent : Colors.grey[300]!,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? Colors.white : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.grey[400]!,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Icon(Icons.check, size: 16, color: primaryA)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 15,
                    color: isSelected ? Colors.white : Colors.grey[800],
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
