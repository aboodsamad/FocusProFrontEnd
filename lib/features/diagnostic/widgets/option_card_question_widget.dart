import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/diagnostic_question.dart';

/// Glassmorphic option cards — web-safe (no BackdropFilter on web).
class OptionCardQuestionWidget extends StatefulWidget {
  final DiagnosticQuestion question;
  final void Function(DiagnosticAnswer answer) onAnswered;
  const OptionCardQuestionWidget({super.key, required this.question, required this.onAnswered});
  @override State<OptionCardQuestionWidget> createState() => _State();
}

class _State extends State<OptionCardQuestionWidget>
    with SingleTickerProviderStateMixin {

  int?  _selected;
  bool  _advancing = false;
  late AnimationController _nextCtrl;
  late Animation<double>   _nextFade;
  late Animation<Offset>   _nextSlide;

  @override
  void initState() {
    super.initState();
    _nextCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _nextFade  = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _nextCtrl, curve: Curves.easeOut));
    _nextSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
        CurvedAnimation(parent: _nextCtrl, curve: Curves.easeOutCubic));
  }

  @override void dispose() { _nextCtrl.dispose(); super.dispose(); }

  void _pick(int i) {
    if (_advancing) return;
    HapticFeedback.lightImpact();
    setState(() => _selected = i);
    _nextCtrl.forward();
    Future.delayed(const Duration(milliseconds: 340), () {
      if (!mounted) return;
      setState(() => _advancing = true);
      final letters = ['A','B','C','D'];
      widget.onAnswered(DiagnosticAnswer(
        questionId: widget.question.id,
        selectedOption: letters[i],
        pointsEarned: widget.question.points[i],
      ));
    });
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    ...List.generate(4, (i) => _OptionTile(
      letter: ['A','B','C','D'][i],
      text:   widget.question.options[i],
      selected: _selected == i,
      onTap: () => _pick(i),
    )),
    const SizedBox(height: 6),
    SlideTransition(
      position: _nextSlide,
      child: FadeTransition(
        opacity: _nextFade,
        child: GestureDetector(
          onTap: _selected != null && !_advancing ? () => _pick(_selected!) : null,
          child: Container(
            width: double.infinity, height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.88),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.2), blurRadius: 30, offset: const Offset(0,8))],
            ),
            child: const Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('Next', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w900)),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 18),
            ])),
          ),
        ),
      ),
    ),
  ]);
}

// ── Individual tile ───────────────────────────────────────────────────────────
class _OptionTile extends StatefulWidget {
  final String letter, text;
  final bool   selected;
  final VoidCallback onTap;
  const _OptionTile({required this.letter, required this.text, required this.selected, required this.onTap});
  @override State<_OptionTile> createState() => _TileState();
}

class _TileState extends State<_OptionTile> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _scale = Tween<double>(begin: 1.0, end: 1.02)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
  }

  @override
  void didUpdateWidget(_OptionTile old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected) _ctrl.forward();
    else if (!widget.selected && old.selected) _ctrl.reverse();
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ScaleTransition(
        scale: _scale,
        child: GestureDetector(
          onTap: widget.onTap,
          child: _buildCard(),
        ),
      ),
    );
  }

  Widget _buildCard() {
    final decoration = BoxDecoration(
      color: widget.selected ? Colors.white.withOpacity(0.14) : Colors.white.withOpacity(0.07),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: widget.selected ? Colors.white.withOpacity(0.4) : Colors.white.withOpacity(0.1),
        width: 1.5,
      ),
    );

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: decoration,
      child: Row(children: [
        // Letter badge
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: widget.selected ? Colors.white : Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.selected ? Colors.transparent : Colors.white.withOpacity(0.12),
              width: 1.5,
            ),
            boxShadow: widget.selected
                ? [BoxShadow(color: Colors.white.withOpacity(0.35), blurRadius: 14)] : null,
          ),
          child: Center(child: Text(widget.letter,
              style: TextStyle(
                color: widget.selected ? Colors.black : Colors.white.withOpacity(0.4),
                fontSize: 13, fontWeight: FontWeight.w900))),
        ),
        const SizedBox(width: 13),
        Expanded(child: Text(widget.text,
            style: TextStyle(
              color: widget.selected ? Colors.white : Colors.white.withOpacity(0.55),
              fontSize: 14,
              fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
              height: 1.35))),
        const SizedBox(width: 8),
        AnimatedOpacity(
          opacity: widget.selected ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: 24, height: 24,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Center(child: Icon(Icons.check_rounded, color: Colors.black, size: 14)),
          ),
        ),
      ]),
    );

    if (kIsWeb) return content;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: content,
      ),
    );
  }
}
