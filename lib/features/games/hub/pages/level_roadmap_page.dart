import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../services/game_progress_service.dart';

// ── Layout constants ──────────────────────────────────────────────────────────
const double _nodeSize        = 64.0;
const double _currentNodeSize = 96.0;
const double _outerRingSize   = _currentNodeSize + 16;
const double _innerRingSize   = _currentNodeSize + 8;
const double _vStep           = 180.0;
const double _topPad          = 24.0;
const double _bottomPad       = 220.0;
const double _cardWidth       = 118.0;
const double _leftFraction    = 0.28;
const double _rightFraction   = 0.72;

// ── LevelRoadmapPage ──────────────────────────────────────────────────────────
class LevelRoadmapPage extends StatefulWidget {
  final String gameId;
  final String title;
  final Color  color;
  final int    totalLevels;

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

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.3, end: 1.0)
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
    _loadProgress();
  }

  _NodeState _nodeState(int level) {
    if (level < _maxUnlocked)  return _NodeState.completed;
    if (level == _maxUnlocked) return _NodeState.current;
    return _NodeState.locked;
  }

  // Y center for every node in the Stack coordinate space
  double _nodeCenterY(int index) =>
      _topPad + index * _vStep + _nodeSize / 2;

  double _nodeCenterX(int index, double width) =>
      index % 2 == 0 ? width * _leftFraction : width * _rightFraction;

  double get _totalHeight =>
      _topPad + widget.totalLevels * _vStep + _bottomPad;

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(context),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        _buildHeroSection(),
                        LayoutBuilder(
                          builder: (ctx, constraints) {
                            final width = constraints.maxWidth;
                            return SizedBox(
                              height: _totalHeight,
                              width: width,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  // Subtle background panel
                                  Positioned.fill(
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceContainerLow.withValues(alpha: 0.45),
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                    ),
                                  ),
                                  // Dashed connecting path
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _PathPainter(
                                        totalLevels: widget.totalLevels,
                                        width: width,
                                      ),
                                    ),
                                  ),
                                  // Level nodes
                                  ...List.generate(widget.totalLevels, (i) {
                                    final level  = i + 1;
                                    final state  = _nodeState(level);
                                    final centerY = _nodeCenterY(i);
                                    final centerX = _nodeCenterX(i, width);
                                    final isLeft  = i % 2 == 0;

                                    if (state == _NodeState.current) {
                                      // Centered current node with pulsing rings
                                      return Positioned(
                                        left:  0,
                                        right: 0,
                                        top:   centerY - _outerRingSize / 2,
                                        child: Center(
                                          child: _buildCurrentColumn(level),
                                        ),
                                      );
                                    }

                                    // Completed or locked row
                                    final rowLeft = isLeft
                                        ? centerX - _nodeSize / 2
                                        : centerX - _nodeSize / 2 - 8 - _cardWidth;

                                    return Positioned(
                                      left: rowLeft,
                                      top:  centerY - _nodeSize / 2,
                                      child: GestureDetector(
                                        onTap: state != _NodeState.locked
                                            ? () => _openLevel(level)
                                            : null,
                                        child: _buildNodeRow(level, state, isLeft),
                                      ),
                                    );
                                  }),
                                  // Motivational quote at the bottom
                                  Positioned(
                                    bottom: 20,
                                    left:   24,
                                    right:  24,
                                    child:  _buildQuoteCard(),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
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

  // ── Top bar ───────────────────────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context) {
    final progress = _maxUnlocked / widget.totalLevels;
    return Container(
      color: const Color(0xFFF0FBF5),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.onSurfaceVariant,
                size: 16,
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3.5,
                  backgroundColor: AppColors.secondary.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero section ──────────────────────────────────────────────────────────────
  Widget _buildHeroSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Column(
        children: [
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color:      AppColors.primary,
              fontSize:   32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Consistency is the bridge between goals and accomplishment. Keep moving forward.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color:    AppColors.onSurfaceVariant,
              fontSize: 15,
              height:   1.5,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Completed / locked row ────────────────────────────────────────────────────
  Widget _buildNodeRow(int level, _NodeState state, bool isLeft) {
    final circle = _buildCircle(level, state);
    final card   = _buildLevelCard(level, state, isLeft);

    return Opacity(
      opacity: state == _NodeState.locked ? 0.55 : 1.0,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: isLeft
            ? [circle, const SizedBox(width: 8), card]
            : [card,   const SizedBox(width: 8), circle],
      ),
    );
  }

  Widget _buildCircle(int level, _NodeState state) {
    final bool isCompleted = state == _NodeState.completed;
    final Color bg = isCompleted
        ? AppColors.secondary
        : AppColors.surfaceContainerHigh;
    final Color iconColor = isCompleted ? Colors.white : AppColors.outline;
    final IconData icon   = isCompleted
        ? (level % 2 == 0 ? Icons.star_rounded : Icons.check_rounded)
        : Icons.lock_rounded;

    return Container(
      width:  _nodeSize,
      height: _nodeSize,
      decoration: BoxDecoration(
        shape:     BoxShape.circle,
        color:     bg,
        boxShadow: isCompleted
            ? [
                BoxShadow(
                  color:      AppColors.secondary.withValues(alpha: 0.25),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Icon(icon, color: iconColor, size: 26),
    );
  }

  Widget _buildLevelCard(int level, _NodeState state, bool isLeft) {
    final bool isLocked = state == _NodeState.locked;
    return Container(
      width: _cardWidth,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isLocked
            ? AppColors.surfaceContainerLow
            : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isLocked
            ? null
            : [
                BoxShadow(
                  color:     Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset:    const Offset(0, 2),
                ),
              ],
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Level $level',
            style: TextStyle(
              color:      isLocked ? AppColors.onSurfaceVariant : AppColors.secondary,
              fontSize:   13,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            _levelName(level),
            style: const TextStyle(
              color:    AppColors.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ── Current level column (centered) ──────────────────────────────────────────
  Widget _buildCurrentColumn(int level) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Outer pulse ring
                Container(
                  width:  _outerRingSize,
                  height: _outerRingSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: _pulseAnim.value * 0.06),
                  ),
                ),
                // Inner pulse ring
                Container(
                  width:  _innerRingSize,
                  height: _innerRingSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: _pulseAnim.value * 0.12),
                  ),
                ),
                // Main circle
                GestureDetector(
                  onTap: () => _openLevel(level),
                  child: Container(
                    width:  _currentNodeSize,
                    height: _currentNodeSize,
                    decoration: BoxDecoration(
                      shape:     BoxShape.circle,
                      color:     AppColors.primary,
                      boxShadow: [
                        BoxShadow(
                          color:      AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'CURRENT',
                          style: TextStyle(
                            color:       Colors.white70,
                            fontSize:    10,
                            fontWeight:  FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          '$level',
                          style: const TextStyle(
                            color:      Colors.white,
                            fontSize:   30,
                            fontWeight: FontWeight.w800,
                            height:     1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        // Name card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color:        AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border:       Border.all(color: AppColors.primaryContainer, width: 2),
            boxShadow: [
              BoxShadow(
                color:     Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset:    const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _levelName(level),
                style: const TextStyle(
                  color:      AppColors.primary,
                  fontSize:   14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                'Tap to play',
                style: TextStyle(
                  color:     AppColors.onSurfaceVariant,
                  fontSize:  11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Quote card ────────────────────────────────────────────────────────────────
  Widget _buildQuoteCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.tertiaryContainer.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.tertiaryContainer.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.format_quote_rounded,
            color: AppColors.tertiaryContainer,
            size:  28,
          ),
          const SizedBox(height: 8),
          const Text(
            '"Progress is not in enhancing what is, but in moving toward what will be."',
            textAlign: TextAlign.center,
            style: TextStyle(
              color:      AppColors.tertiaryContainer,
              fontSize:   15,
              fontWeight: FontWeight.w600,
              fontStyle:  FontStyle.italic,
              height:     1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Level name helper ─────────────────────────────────────────────────────────
  String _levelName(int level) {
    const names = [
      'The First Breath', 'Quiet Mind',    'Flow State',
      'Rhythmic Focus',   'Clarity Peak',  'Unlocking Zenith',
      'Infinite Calm',    'Mindful Master','The Summit',      'Mastery',
    ];
    return level <= names.length ? names[level - 1] : 'Advanced';
  }
}

// ── Node state ────────────────────────────────────────────────────────────────
enum _NodeState { completed, current, locked }

// ── Path painter ──────────────────────────────────────────────────────────────
class _PathPainter extends CustomPainter {
  final int    totalLevels;
  final double width;

  const _PathPainter({required this.totalLevels, required this.width});

  Offset _center(int index) {
    final y = _topPad + index * _vStep + _nodeSize / 2;
    final x = index % 2 == 0
        ? width * _leftFraction
        : width * _rightFraction;
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 2.0
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round
      ..color       = AppColors.outlineVariant.withValues(alpha: 0.55);

    for (int i = 0; i < totalLevels - 1; i++) {
      final from = _center(i);
      final to   = _center(i + 1);

      final angle  = (to - from).direction;
      final startP = from + Offset.fromDirection(angle, _nodeSize / 2 + 4);
      final endP   = to   - Offset.fromDirection(angle, _nodeSize / 2 + 4);

      _drawDashedLine(canvas, startP, endP, paint);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashLen = 8.0;
    const gapLen  = 6.0;
    final total   = (end - start).distance;
    if (total == 0) return;
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
      drawing  = !drawing;
    }
  }

  @override
  bool shouldRepaint(_PathPainter old) => false;
}
