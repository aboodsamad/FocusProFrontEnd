import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MemoryMatrixIdleScreen
// ─────────────────────────────────────────────────────────────────────────────

/// The landing screen shown before the game starts or after game-over.
/// Contains the animated [_MiniGridPreview] and the Start / Play Again button.
class MemoryMatrixIdleScreen extends StatelessWidget {
  final VoidCallback onStart;

  const MemoryMatrixIdleScreen({super.key, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _MiniGridPreview(),
            const SizedBox(height: 36),
            const Text(
              'Memory Matrix',
              style: TextStyle(
                color:       Colors.white,
                fontSize:    30,
                fontWeight:  FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Watch the pattern light up.\nTap the same cells to score.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color:    Color(0xFF6B7A99),
                fontSize: 15,
                height:   1.6,
              ),
            ),
            const SizedBox(height: 48),
            _StartButton(onTap: onStart),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MiniGridPreview  (private — only used by MemoryMatrixIdleScreen)
// ─────────────────────────────────────────────────────────────────────────────

/// 3 × 3 preview grid that cycles random lit cells to demo the mechanic.
class _MiniGridPreview extends StatefulWidget {
  const _MiniGridPreview();

  @override
  State<_MiniGridPreview> createState() => _MiniGridPreviewState();
}

class _MiniGridPreviewState extends State<_MiniGridPreview> {
  final Set<int> _lit = {};
  Timer?         _timer;

  static const _cellCount = 9;
  static const _litCount  = 4;

  @override
  void initState() {
    super.initState();
    _cycle();
    _timer = Timer.periodic(const Duration(milliseconds: 700), (_) => _cycle());
  }

  void _cycle() {
    if (!mounted) return;
    final rnd = Random();
    final next = <int>{};
    while (next.length < _litCount) next.add(rnd.nextInt(_cellCount));
    setState(() {
      _lit
        ..clear()
        ..addAll(next);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width:  110,
      height: 110,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:   3,
          crossAxisSpacing: 7,
          mainAxisSpacing:  7,
        ),
        itemCount: _cellCount,
        itemBuilder: (_, i) {
          final active = _lit.contains(i);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve:    Curves.easeInOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: active
                  ? const Color(0xFF7B6FFF)
                  : const Color(0xFF151C2E),
              border: Border.all(
                color: active
                    ? const Color(0xFF7B6FFF).withOpacity(0.5)
                    : const Color(0xFF1E2840),
              ),
              boxShadow: active
                  ? [BoxShadow(
                      color:      const Color(0xFF7B6FFF).withOpacity(0.4),
                      blurRadius: 10,
                    )]
                  : null,
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StartButton  (private)
// ─────────────────────────────────────────────────────────────────────────────

class _StartButton extends StatelessWidget {
  final VoidCallback onTap;

  const _StartButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:   double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3D6EFF), Color(0xFF5B8FFF)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color:  const Color(0xFF5B8FFF).withOpacity(0.4),
              blurRadius:  24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'Start Game',
            style: TextStyle(
              color:       Colors.white,
              fontWeight:  FontWeight.w700,
              fontSize:    16,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}
