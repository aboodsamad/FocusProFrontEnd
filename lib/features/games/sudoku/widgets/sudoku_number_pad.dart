import 'package:capstone_front_end/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SudokuNumberPad
// ─────────────────────────────────────────────────────────────────────────────

class SudokuNumberPad extends StatelessWidget {
  final List<List<int>> board;
  final int selectedValue;
  final void Function(int) onNumberPressed;

  const SudokuNumberPad({
    super.key,
    required this.board,
    required this.selectedValue,
    required this.onNumberPressed,
  });

  int _count(int number) {
    int n = 0;
    for (final row in board) for (final cell in row) if (cell == number) n++;
    return n;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(9, (i) {
        final number     = i + 1;
        final count      = _count(number);
        final isComplete = count >= 9;
        final isActive   = selectedValue == number;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _NumberButton(
              number:     number,
              remaining:  9 - count,
              isComplete: isComplete,
              isActive:   isActive,
              onTap:      isComplete ? null : () => onNumberPressed(number),
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual number button
// ─────────────────────────────────────────────────────────────────────────────

class _NumberButton extends StatefulWidget {
  final int number;
  final int remaining;
  final bool isComplete;
  final bool isActive;
  final VoidCallback? onTap;

  const _NumberButton({
    required this.number,
    required this.remaining,
    required this.isComplete,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_NumberButton> createState() => _NumberButtonState();
}

class _NumberButtonState extends State<_NumberButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final Color textColor;
    final Color bgColor;

    if (widget.isComplete) {
      textColor = AppColors.outlineVariant;
      bgColor   = AppColors.surfaceContainerLow;
    } else if (widget.isActive) {
      textColor = AppColors.onPrimary;
      bgColor   = AppColors.primary;
    } else {
      textColor = AppColors.primary;
      bgColor   = _pressed
          ? AppColors.surfaceContainer
          : AppColors.surfaceContainerLowest;
    }

    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) => setState(() => _pressed = false),
      onTapCancel: ()  => setState(() => _pressed = false),
      onTap:       widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 52,
        decoration: BoxDecoration(
          color:        bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.number.toString(),
              style: TextStyle(
                fontSize:   20,
                fontWeight: FontWeight.bold,
                color:      textColor,
              ),
            ),
            if (!widget.isComplete) ...[
              const SizedBox(height: 3),
              _RemainingDots(remaining: widget.remaining, isActive: widget.isActive),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tiny dots showing how many of this digit are left to place
// ─────────────────────────────────────────────────────────────────────────────

class _RemainingDots extends StatelessWidget {
  final int  remaining;
  final bool isActive;
  const _RemainingDots({required this.remaining, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? AppColors.onPrimary.withOpacity(0.7)
        : AppColors.primary.withOpacity(0.3);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        remaining.clamp(0, 5),
        (_) => Container(
          width: 3, height: 3,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SudokuActionButtons  (Hint + Erase)
// ─────────────────────────────────────────────────────────────────────────────

class SudokuActionButtons extends StatelessWidget {
  final VoidCallback onHint;
  final VoidCallback onErase;

  const SudokuActionButtons({
    super.key,
    required this.onHint,
    required this.onErase,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _ActionBtn(
          icon:    Icons.lightbulb_outline_rounded,
          label:   'Hint',
          color:   AppColors.secondary,
          onTap:   onHint,
        )),
        const SizedBox(width: 12),
        Expanded(child: _ActionBtn(
          icon:    Icons.backspace_outlined,
          label:   'Erase',
          color:   AppColors.error,
          onTap:   onErase,
        )),
      ],
    );
  }
}

class _ActionBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) => setState(() => _pressed = false),
      onTapCancel: ()  => setState(() => _pressed = false),
      onTap:       widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color:        widget.color.withOpacity(_pressed ? 0.12 : 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, color: widget.color, size: 18),
            const SizedBox(width: 7),
            Text(widget.label,
                style: TextStyle(color: widget.color, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
