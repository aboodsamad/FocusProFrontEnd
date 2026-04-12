import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/game_progress_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const _kBg        = Color(0xFF06090F);
const _kSurface   = Color(0xFF0D1421);
const _kDimBorder = Color(0xFF1E2840);

const double _nodeSize      = 74.0;
const double _vStep         = 130.0;  // vertical distance between node centres
const double _topPad        = 32.0;
const double _bottomPad     = 56.0;
const double _leftFraction  = 0.28;
const double _rightFraction = 0.72;

// ─────────────────────────────────────────────────────────────────────────────
// LevelRoadmapPage
// ─────────────────────────────────────────────────────────────────────────────

class LevelRoadmapPage extends StatefulWidget {
  final String gameId;
  final String title;
  final Color  color;
  final int    totalLevels;

  /// Builds the game widget for [startLevel].
  final Widget Function(int startLevel) pageBuilder;

  const LevelRoadmapPage({
    super.key,
    required this.gameId,
    required this.title,
    required this.color,
    required this.totalLevels,
    required this.pageBuilder,
  });

  @override
  State<LevelRoadmapPage> createState() => _LevelRoadmapPageState();
}

class _LevelRoadmapPageState extends State<LevelRoadmapPage>
    with TickerProviderStateMixin {

  int _maxUnlocked = 1;

  // Pulsing glow for the frontier node
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  // Fade-in for page
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _fadeCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 420),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _loadProgress();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Data ────────────────────────────────────────────────────────────────────

  Future<void> _loadProgress() async {
    final level = await GameProgressService.getMaxUnlockedLevel(widget.gameId);
    if (mounted) setState(() => _maxUnlocked = level);
  }

  void _openLevel(int level) async {
    HapticFeedback.mediumImpact();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => widget.pageBuilder(level)),
    );
    // Refresh unlock state after returning
    _loadProgress();
  }

  // ── Geometry helpers ────────────────────────────────────────────────────────

  double get _totalHeight =>
      _topPad + widget.totalLevels * _vStep + _bottomPad;

  Offset _nodeCenter(int index, double width) {
    final y = _topPad + index * _vStep + _nodeSize / 2;
    final x = index % 2 == 0
        ? width * _leftFraction
        : width * _rightFraction;
    return Offset(x, y);
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _kBg,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                      child: LayoutBuilder(
                        builder: (ctx, constraints) {
                          final width = constraints.maxWidth;
                          return SizedBox(
                            height: _totalHeight,
                            width: width,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // ── Path ──────────────────────────────────────
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _PathPainter(
                                      totalLevels: widget.totalLevels,
                                      maxUnlocked: _maxUnlocked,
                                      gameColor:   widget.color,
                                      width:       width,
                                    ),
                                  ),
                                ),
                                // ── Nodes ─────────────────────────────────────
                                ...List.generate(widget.totalLevels, (i) {
                                  final level   = i + 1;
                                  final center  = _nodeCenter(i, width);
                                  final state   = _nodeState(level);
                                  final canTap  = state != _NodeState.locked;

                                  return Positioned(
                                    left: center.dx - _nodeSize / 2,
                                    top:  center.dy - _nodeSize / 2,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        GestureDetector(
                                          onTap: canTap ? () => _openLevel(level) : null,
                                          child: _buildNode(level, state),
                                        ),
                                        const SizedBox(height: 8),
                                        _buildNodeLabel(level, state),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
      decoration: BoxDecoration(
        color: _kBg,
        border: Border(
          bottom: BorderSide(color: widget.color.withOpacity(0.12), width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            splashRadius: 24,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_maxUnlocked / ${widget.totalLevels} levels unlocked',
                  style: TextStyle(
                    color: widget.color.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Progress indicator
          _buildProgressRing(),
        ],
      ),
    );
  }

  Widget _buildProgressRing() {
    final progress = _maxUnlocked / widget.totalLevels;
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 3.5,
            backgroundColor: widget.color.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation<Color>(widget.color),
          ),
          Text(
            '${(progress * 100).round()}%',
            style: TextStyle(
              color: widget.color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ── Node State ────────────────────────────────────────────────────────────────

  _NodeState _nodeState(int level) {
    if (level < _maxUnlocked)  return _NodeState.completed;
    if (level == _maxUnlocked) return _NodeState.available;
    return _NodeState.locked;
  }

  // ── Node Widget ───────────────────────────────────────────────────────────────

  Widget _buildNode(int level, _NodeState state) {
    return SizedBox(
      width: _nodeSize,
      height: _nodeSize,
      child: switch (state) {
        _NodeState.completed => _CompletedNode(level: level, color: widget.color),
        _NodeState.available => _AvailableNode(
            level:     level,
            color:     widget.color,
            pulseAnim: _pulseAnim,
          ),
        _NodeState.locked    => _LockedNode(level: level),
      },
    );
  }

  Widget _buildNodeLabel(int level, _NodeState state) {
    final Color textColor = switch (state) {
      _NodeState.completed => widget.color.withOpacity(0.9),
      _NodeState.available => Colors.white,
      _NodeState.locked    => Colors.white24,
    };

    final String label = switch (state) {
      _NodeState.completed => 'DONE',
      _NodeState.available => 'LEVEL $level',
      _NodeState.locked    => 'LOCKED',
    };

    return Text(
      label,
      style: TextStyle(
        color:       textColor,
        fontSize:    9.5,
        fontWeight:  state == _NodeState.available ? FontWeight.w700 : FontWeight.w500,
        letterSpacing: 1.0,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Node state enum
// ─────────────────────────────────────────────────────────────────────────────

enum _NodeState { completed, available, locked }

// ─────────────────────────────────────────────────────────────────────────────
// Completed node
// ─────────────────────────────────────────────────────────────────────────────

class _CompletedNode extends StatelessWidget {
  final int   level;
  final Color color;

  const _CompletedNode({required this.level, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape:       BoxShape.circle,
        color:       color,
        boxShadow:   [
          BoxShadow(
            color:   color.withOpacity(0.35),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_rounded, color: Colors.white, size: 26),
            Text(
              '$level',
              style: const TextStyle(
                color:      Colors.white70,
                fontSize:   10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Available (frontier) node
// ─────────────────────────────────────────────────────────────────────────────

class _AvailableNode extends StatelessWidget {
  final int              level;
  final Color            color;
  final Animation<double> pulseAnim;

  const _AvailableNode({
    required this.level,
    required this.color,
    required this.pulseAnim,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, __) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulse ring
            Container(
              width:  _nodeSize,
              height: _nodeSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withOpacity(pulseAnim.value * 0.4),
                  width: 2.5,
                ),
              ),
            ),
            // Inner circle
            Container(
              width:  _nodeSize - 10,
              height: _nodeSize - 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kBg,
                border: Border.all(color: color, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color:      color.withOpacity(pulseAnim.value * 0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$level',
                      style: TextStyle(
                        color:      color,
                        fontSize:   22,
                        fontWeight: FontWeight.w800,
                        height:     1.0,
                      ),
                    ),
                    Icon(
                      Icons.play_arrow_rounded,
                      color: color.withOpacity(0.8),
                      size:  12,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Locked node
// ─────────────────────────────────────────────────────────────────────────────

class _LockedNode extends StatelessWidget {
  final int level;

  const _LockedNode({required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _kSurface,
        border: Border.all(color: _kDimBorder, width: 1.5),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_rounded, color: Colors.white24, size: 22),
            Text(
              '$level',
              style: const TextStyle(
                color:      Colors.white24,
                fontSize:   10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Path painter
// ─────────────────────────────────────────────────────────────────────────────

class _PathPainter extends CustomPainter {
  final int   totalLevels;
  final int   maxUnlocked;
  final Color gameColor;
  final double width;

  const _PathPainter({
    required this.totalLevels,
    required this.maxUnlocked,
    required this.gameColor,
    required this.width,
  });

  Offset _center(int index) {
    final y = _topPad + index * _vStep + _nodeSize / 2;
    final x = index % 2 == 0
        ? width * _leftFraction
        : width * _rightFraction;
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < totalLevels - 1; i++) {
      final from = _center(i);
      final to   = _center(i + 1);

      // Adjust endpoints to start/end at node edges, not centres
      final angle  = (to - from).direction;
      final startP = from + Offset.fromDirection(angle, _nodeSize / 2 + 2);
      final endP   = to   - Offset.fromDirection(angle, _nodeSize / 2 + 2);

      // Path is lit if BOTH connected levels are unlocked
      final isLit = (i + 1) < maxUnlocked; // level i+2 is unlocked

      final paint = Paint()
        ..strokeWidth = isLit ? 3.0 : 2.0
        ..style       = PaintingStyle.stroke
        ..strokeCap   = StrokeCap.round
        ..color       = isLit
            ? gameColor.withOpacity(0.55)
            : Colors.white.withOpacity(0.07);

      if (!isLit) {
        // Dashed line for locked sections
        _drawDashedLine(canvas, startP, endP, paint);
      } else {
        final dy = endP.dy - startP.dy;
        final path = Path()..moveTo(startP.dx, startP.dy);
        path.cubicTo(
          startP.dx, startP.dy + dy * 0.38,
          endP.dx,   endP.dy   - dy * 0.38,
          endP.dx,   endP.dy,
        );
        canvas.drawPath(path, paint);
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashLen = 6.0;
    const gapLen  = 5.0;
    final total   = (end - start).distance;
    final dir     = (end - start) / total;
    var   covered = 0.0;
    var   drawing = true;

    while (covered < total) {
      final segLen = math.min(drawing ? dashLen : gapLen, total - covered);
      if (drawing) {
        canvas.drawLine(
          start + dir * covered,
          start + dir * (covered + segLen),
          paint,
        );
      }
      covered += segLen;
      drawing = !drawing;
    }
  }

  @override
  bool shouldRepaint(_PathPainter old) =>
      old.maxUnlocked != maxUnlocked || old.gameColor != gameColor;
}
