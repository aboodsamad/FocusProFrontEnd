import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Shows a beautiful animated score-gain toast that floats above everything.
/// Slides in from the top, auto-dismisses after 2.5 s.
///
/// Usage:
///   ScoreGainToast.show(context, result.focusScoreGained);
class ScoreGainToast {
  static OverlayEntry? _active;

  static void show(
    BuildContext context,
    double gained, {
    String? source,
  }) {
    if (gained <= 0.0) return;
    _active?.remove();
    _active = null;

    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastWidget(
        gained: gained,
        source: source ?? 'Focus points earned',
        onDone: () {
          entry.remove();
          if (_active == entry) _active = null;
        },
      ),
    );
    _active = entry;
    overlay.insert(entry);
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ToastWidget extends StatefulWidget {
  final double gained;
  final String source;
  final VoidCallback onDone;

  const _ToastWidget({
    required this.gained,
    required this.source,
    required this.onDone,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  Timer? _autoClose;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

    _ctrl.forward();

    _autoClose = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) {
        _ctrl
            .reverse(from: 1.0)
            .then((_) { if (mounted) widget.onDone(); });
      }
    });
  }

  @override
  void dispose() {
    _autoClose?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top + 12;
    return Positioned(
      top: topPad,
      left: 20,
      right: 20,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: _ToastBody(gained: widget.gained, source: widget.source),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ToastBody extends StatelessWidget {
  final double gained;
  final String source;

  const _ToastBody({required this.gained, required this.source});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E6C4A), Color(0xFF064D34)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withOpacity(0.45),
            blurRadius: 28,
            offset: const Offset(0, 10),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Icon bubble ──────────────────────────────────────────────────
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),

          // ── Text ─────────────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '+${gained.toStringAsFixed(1)} focus pts',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.4,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  source,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // ── Brand mark ───────────────────────────────────────────────────
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded,
                  color: Colors.white.withOpacity(0.65), size: 16),
              const SizedBox(height: 2),
              Text(
                'FocusPro',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
