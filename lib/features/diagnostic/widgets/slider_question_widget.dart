import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../models/diagnostic_question.dart';

/// Glassmorphic slider for screen-habits questions.
/// Large coloured thumb · glowing track · animated answer display.
class SliderQuestionWidget extends StatefulWidget {
  final DiagnosticQuestion question;
  final void Function(DiagnosticAnswer answer) onAnswered;
  const SliderQuestionWidget({super.key, required this.question, required this.onAnswered});
  @override State<SliderQuestionWidget> createState() => _SliderQuestionWidgetState();
}

class _SliderQuestionWidgetState extends State<SliderQuestionWidget> {
  double _value = 0.0;
  bool   _touched = false;

  int    get _idx     => _value.round().clamp(0, 3);
  String get _letter  => ['A', 'B', 'C', 'D'][_idx];
  int    get _pts     => widget.question.points[_idx];
  String get _optText => widget.question.options[_idx];

  // Color goes green → blue → orange → red as habits worsen
  static const List<Color> _colors = [
    Color(0xFF34D399),
    Color(0xFF60A5FA),
    Colors.orange,
    Color(0xFFEF4444),
  ];
  Color get _c => _colors[_idx];

  void _submit() => widget.onAnswered(DiagnosticAnswer(
    questionId: widget.question.id, selectedOption: _letter, pointsEarned: _pts));

  Widget _answerDisplay() {
    final inner = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _touched ? _c.withOpacity(0.10) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _touched ? _c.withOpacity(0.35) : Colors.white.withOpacity(0.08),
          width: 1.5,
        ),
      ),
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 40, height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _touched ? _c : Colors.white.withOpacity(0.07),
            boxShadow: _touched
                ? [BoxShadow(color: _c.withOpacity(0.4), blurRadius: 16)]
                : null,
          ),
          child: Center(child: Text(_letter,
              style: TextStyle(
                color: _touched ? Colors.white : Colors.white38,
                fontWeight: FontWeight.w900, fontSize: 16))),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(
          _touched ? _optText : 'Drag the slider to select your answer',
          style: TextStyle(
            color: _touched ? Colors.white : Colors.white38,
            fontSize: 14,
            fontWeight: _touched ? FontWeight.w600 : FontWeight.normal,
            height: 1.35,
          ),
        )),
      ]),
    );

    if (kIsWeb) return inner;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: inner,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── Selected answer display ────────────────────────────────────────
      _answerDisplay(),

      const SizedBox(height: 28),

      // ── Slider ─────────────────────────────────────────────────────────
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor:   _c,
          inactiveTrackColor: Colors.white.withOpacity(0.08),
          thumbColor:         _c,
          thumbShape:         const RoundSliderThumbShape(enabledThumbRadius: 15),
          overlayColor:       _c.withOpacity(0.15),
          trackHeight:        5,
          activeTickMarkColor: Colors.transparent,
          inactiveTickMarkColor: Colors.transparent,
        ),
        child: Slider(
          value: _value, min: 0, max: 3, divisions: 3,
          onChanged: (v) => setState(() { _value = v; _touched = true; }),
        ),
      ),

      // ── Option labels ──────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(4, (i) {
            final active = _idx == i;
            return Expanded(
              child: Text(
                widget.question.options[i],
                textAlign: i == 0 ? TextAlign.left : i == 3 ? TextAlign.right : TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: active ? _colors[i] : Colors.white.withOpacity(0.25),
                  fontWeight: active ? FontWeight.w800 : FontWeight.normal,
                ),
              ),
            );
          }),
        ),
      ),

      const SizedBox(height: 30),

      // ── Confirm button ─────────────────────────────────────────────────
      GestureDetector(
        onTap: _touched ? _submit : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: double.infinity, height: 56,
          decoration: BoxDecoration(
            color: _touched ? Colors.white.withOpacity(0.9) : Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(18),
            boxShadow: _touched
                ? [BoxShadow(color: Colors.white.withOpacity(0.2), blurRadius: 28, offset: const Offset(0, 8))]
                : null,
          ),
          child: Center(
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('Confirm',
                  style: TextStyle(
                    color: _touched ? Colors.black : Colors.white24,
                    fontSize: 16, fontWeight: FontWeight.w900,
                  )),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded,
                  color: _touched ? Colors.black : Colors.white24, size: 18),
            ]),
          ),
        ),
      ),
    ]);
  }
}
