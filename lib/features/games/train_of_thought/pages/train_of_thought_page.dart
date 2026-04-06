import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../features/home/providers/user_provider.dart';
import '../../services/game_service.dart';
import '../models/train_of_thought_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Theme constants
// ─────────────────────────────────────────────────────────────────────────────
const _kBg       = Color(0xFF06090F);
const _kSurface  = Color(0xFF0F1420);
const _kBorder   = Color(0xFF1E2840);
const _kAccent   = Color(0xFF5B8FFF);
const _kGold     = Color(0xFFFFD166);
const _kWrong    = Color(0xFFFF5270);
const _kMuted    = Color(0xFF6B7A99);
const _kText     = Colors.white;

Color _trainColor(TrainColor c) {
  switch (c) {
    case TrainColor.red:    return const Color(0xFFFF5270);
    case TrainColor.blue:   return const Color(0xFF5B8FFF);
    case TrainColor.green:  return const Color(0xFF4ADE80);
    case TrainColor.yellow: return const Color(0xFFFFD166);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Train of Thought Page
// ─────────────────────────────────────────────────────────────────────────────

class TrainOfThoughtPage extends StatefulWidget {
  const TrainOfThoughtPage({super.key});

  @override
  State<TrainOfThoughtPage> createState() => _TrainOfThoughtPageState();
}

class _TrainOfThoughtPageState extends State<TrainOfThoughtPage>
    with TickerProviderStateMixin {

  // ── State ──────────────────────────────────────────────────────────────────
  late TrainOfThoughtState _game;
  bool _gameInitialized = false;
  Timer? _tickTimer;
  int _startTimeEpoch = 0;

  // Smooth train positions: trainIdx → [row, col] as doubles (for animation)
  final Map<int, Offset> _trainAnimPos = {};

  // Mistake flash animation
  late AnimationController _mistakeAnim;
  // Win pulse animation
  late AnimationController _winAnim;
  // Idle floating animation
  late AnimationController _idleAnim;

  // Per-train animation controllers for smooth movement
  final Map<int, AnimationController> _trainMoveAnims = {};

  @override
  void initState() {
    super.initState();
    _mistakeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _winAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _idleAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _loadLevel(1);
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _mistakeAnim.dispose();
    _winAnim.dispose();
    _idleAnim.dispose();
    for (final c in _trainMoveAnims.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Level management ───────────────────────────────────────────────────────

  void _loadLevel(int level, {bool resetProgress = false}) {
    _tickTimer?.cancel();
    final def = LevelFactory.buildLevel(level);

    // Dispose old train move controllers
    for (final c in _trainMoveAnims.values) { c.dispose(); }
    _trainMoveAnims.clear();
    _trainAnimPos.clear();

    // Create new per-train controllers
    for (int i = 0; i < def.trains.length; i++) {
      final ctrl = AnimationController(
        vsync: this,
        duration: def.tickInterval,
      );
      _trainMoveAnims[i] = ctrl;
      _trainAnimPos[i] = Offset(
        def.trains[i].col.toDouble(),
        def.trains[i].row.toDouble(),
      );
    }

    final carryScore    = (!resetProgress && _gameInitialized) ? _game.score    : 0;
    final carryMistakes = (!resetProgress && _gameInitialized) ? _game.mistakes : 0;

    final newState = TrainOfThoughtState(
      level: level,
      score: carryScore,
      mistakes: carryMistakes,
      phase: GamePhase.idle,
      grid: def.grid,
      trains: def.trains,
      rows: def.rows,
      cols: def.cols,
      tickInterval: def.tickInterval,
    );

    if (_gameInitialized) {
      setState(() { _game = newState; });
    } else {
      _game = newState;
      _gameInitialized = true;
    }
  }

  void _startGame() {
    _startTimeEpoch = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _game = _game.copyWith(phase: GamePhase.playing);
    });
    _scheduleTick();
  }

  void _scheduleTick() {
    _tickTimer?.cancel();
    _tickTimer = Timer(_game.tickInterval, _onTick);
  }

  // ── Game tick ──────────────────────────────────────────────────────────────

  void _onTick() {
    if (_game.phase != GamePhase.playing) return;

    final grid = _game.grid;
    final trains = List<Train>.from(_game.trains);
    int newMistakes = _game.mistakes;
    int newScore = _game.score;

    for (int i = 0; i < trains.length; i++) {
      final t = trains[i];
      if (!t.alive) continue;

      // Compute next cell
      final nextRow = t.row + t.direction.dRow;
      final nextCol = t.col + t.direction.dCol;

      // Out of bounds → derail (mistake)
      if (nextRow < 0 || nextRow >= _game.rows ||
          nextCol < 0 || nextCol >= _game.cols) {
        trains[i] = t.copyWith(alive: false, crashed: true);
        newMistakes++;
        HapticFeedback.heavyImpact();
        continue;
      }

      final nextCell = grid[nextRow][nextCol];

      // ── Station ────────────────────────────────────────────────────────────
      if (nextCell.isStation) {
        if (nextCell.stationColor == t.color) {
          // Correct station!
          trains[i] = t.copyWith(row: nextRow, col: nextCol, alive: false, arrived: true);
          newScore += 100 + (_game.level * 20);
          HapticFeedback.selectionClick();
          _startTrainMoveAnim(i, nextRow.toDouble(), nextCol.toDouble());
        } else {
          // Wrong station!
          trains[i] = t.copyWith(row: nextRow, col: nextCol, alive: false, crashed: true);
          newMistakes++;
          HapticFeedback.heavyImpact();
          _mistakeAnim.forward(from: 0);
        }
        continue;
      }

      // ── Regular track / junction ───────────────────────────────────────────
      if (nextCell.isEmpty) {
        // Off track → derail
        trains[i] = t.copyWith(alive: false, crashed: true);
        newMistakes++;
        HapticFeedback.heavyImpact();
        continue;
      }

      // Find exit port
      final entryPort = t.direction.entryPort;
      final exitPort = nextCell.exitPort(entryPort);

      if (exitPort == null) {
        // Can't route through this cell
        trains[i] = t.copyWith(alive: false, crashed: true);
        newMistakes++;
        HapticFeedback.heavyImpact();
        continue;
      }

      final newDir = exitPort.exitDir;
      trains[i] = t.copyWith(row: nextRow, col: nextCol, direction: newDir);
      _startTrainMoveAnim(i, nextRow.toDouble(), nextCol.toDouble());
    }

    // Check game-over condition
    if (newMistakes >= 3) {
      _tickTimer?.cancel();
      setState(() {
        _game = _game.copyWith(
          trains: trains,
          mistakes: newMistakes,
          score: newScore,
          phase: GamePhase.gameOver,
        );
      });
      _submitResult(completed: false);
      return;
    }

    // Check level complete
    final allDone = trains.every((t) => !t.alive);
    if (allDone) {
      _tickTimer?.cancel();
      newScore += (3 - newMistakes) * 50; // bonus for fewer mistakes
      setState(() {
        _game = _game.copyWith(
          trains: trains,
          mistakes: newMistakes,
          score: newScore,
          phase: GamePhase.levelComplete,
        );
      });
      _winAnim.forward(from: 0);
      HapticFeedback.selectionClick();
      _submitResult(completed: true);
      return;
    }

    setState(() {
      _game = _game.copyWith(
        trains: trains,
        mistakes: newMistakes,
        score: newScore,
      );
    });
    _scheduleTick();
  }

  void _startTrainMoveAnim(int idx, double toRow, double toCol) {
    final ctrl = _trainMoveAnims[idx];
    if (ctrl == null) return;
    final from = _trainAnimPos[idx] ?? Offset(toCol, toRow);
    final to = Offset(toCol, toRow);

    ctrl.stop();
    ctrl.reset();

    final anim = Tween<Offset>(begin: from, end: to).animate(
      CurvedAnimation(parent: ctrl, curve: Curves.easeInOut),
    );

    anim.addListener(() {
      if (mounted) {
        setState(() {
          _trainAnimPos[idx] = anim.value;
        });
      }
    });

    ctrl.forward();
    _trainAnimPos[idx] = to;
  }

  // ── Junction tap ───────────────────────────────────────────────────────────

  void _onCellTap(int row, int col) {
    if (_game.phase != GamePhase.playing) return;
    final cell = _game.grid[row][col];
    if (!cell.isJunction) return;

    HapticFeedback.selectionClick();

    final newGrid = _game.grid.map((r) => List<TrackCell>.from(r)).toList();
    newGrid[row][col] = cell.copyWith(activeIdx: 1 - cell.activeIdx);

    setState(() {
      _game = _game.copyWith(grid: newGrid);
    });
  }

  // ── Backend ────────────────────────────────────────────────────────────────

  Future<void> _submitResult({required bool completed}) async {
    final elapsed =
        (DateTime.now().millisecondsSinceEpoch - _startTimeEpoch) ~/ 1000;
    final result = await GameService.submitResult(
      gameType: 'train_of_thought',
      score: _game.score,
      timePlayedSeconds: elapsed,
      completed: completed,
      levelReached: _game.level,
      mistakes: _game.mistakes,
    );
    if (result != null && mounted) {
      context.read<UserProvider>().updateFocusScore(result.newFocusScore);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _TopBar(
                  level: _game.level,
                  score: _game.score,
                  mistakes: _game.mistakes,
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: _buildGameArea(),
                ),
              ],
            ),

            // ── Overlays ────────────────────────────────────────────────────
            if (_game.phase == GamePhase.idle)
              _IdleOverlay(
                level: _game.level,
                idleAnim: _idleAnim,
                onStart: _startGame,
              ),
            if (_game.phase == GamePhase.levelComplete)
              _LevelCompleteOverlay(
                level: _game.level,
                score: _game.score,
                stars: _game.stars,
                winAnim: _winAnim,
                onNext: () {
                  _winAnim.reset();
                  _loadLevel(_game.level + 1, resetProgress: false);
                  Future.delayed(const Duration(milliseconds: 200), _startGame);
                },
              ),
            if (_game.phase == GamePhase.gameOver)
              _GameOverOverlay(
                score: _game.score,
                level: _game.level,
                onRetry: () {
                  _loadLevel(_game.level, resetProgress: true);
                  Future.delayed(const Duration(milliseconds: 200), _startGame);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate cell size to fit grid
        final padding = 12.0;
        final availW = constraints.maxWidth - padding * 2;
        final availH = constraints.maxHeight - padding * 2;
        final cellW = availW / _game.cols;
        final cellH = availH / _game.rows;
        final cellSize = min(cellW, cellH).clamp(24.0, 72.0);
        final gridW = cellSize * _game.cols;
        final gridH = cellSize * _game.rows;

        return Center(
          child: SizedBox(
            width: gridW,
            height: gridH,
            child: Stack(
              children: [
                // Track layer
                CustomPaint(
                  size: Size(gridW, gridH),
                  painter: _TrackPainter(
                    grid: _game.grid,
                    rows: _game.rows,
                    cols: _game.cols,
                    cellSize: cellSize,
                  ),
                ),
                // Tap layer for junctions
                ..._buildJunctionTapTargets(cellSize),
                // Train layer
                ..._buildTrainWidgets(cellSize),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildJunctionTapTargets(double cellSize) {
    final targets = <Widget>[];
    for (int r = 0; r < _game.rows; r++) {
      for (int c = 0; c < _game.cols; c++) {
        final cell = _game.grid[r][c];
        if (!cell.isJunction) continue;
        targets.add(
          Positioned(
            left: c * cellSize,
            top: r * cellSize,
            width: cellSize,
            height: cellSize,
            child: GestureDetector(
              onTap: () => _onCellTap(r, c),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _kAccent.withOpacity(0.5),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        );
      }
    }
    return targets;
  }

  List<Widget> _buildTrainWidgets(double cellSize) {
    final widgets = <Widget>[];
    for (int i = 0; i < _game.trains.length; i++) {
      final t = _game.trains[i];
      final animPos = _trainAnimPos[i] ?? Offset(t.col.toDouble(), t.row.toDouble());
      final color = _trainColor(t.color);

      double opacity = t.alive ? 1.0 : (t.arrived ? 0.0 : 0.6);
      if (!t.alive && !t.arrived && !t.crashed) opacity = 0.0;

      widgets.add(
        Positioned(
          left: animPos.dx * cellSize + cellSize * 0.1,
          top: animPos.dy * cellSize + cellSize * 0.1,
          width: cellSize * 0.8,
          height: cellSize * 0.8,
          child: AnimatedOpacity(
            opacity: opacity,
            duration: const Duration(milliseconds: 300),
            child: _TrainWidget(
              color: color,
              direction: t.direction,
              crashed: t.crashed,
              cellSize: cellSize * 0.8,
            ),
          ),
        ),
      );
    }
    return widgets;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Track Painter
// ─────────────────────────────────────────────────────────────────────────────

class _TrackPainter extends CustomPainter {
  final List<List<TrackCell>> grid;
  final int rows;
  final int cols;
  final double cellSize;

  const _TrackPainter({
    required this.grid,
    required this.rows,
    required this.cols,
    required this.cellSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final trackPaint = Paint()
      ..color = const Color(0xFF2A3A5C)
      ..strokeWidth = cellSize * 0.22
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final railPaint = Paint()
      ..color = const Color(0xFF3D5080)
      ..strokeWidth = cellSize * 0.06
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final juncPaint = Paint()
      ..color = _kAccent.withOpacity(0.9)
      ..strokeWidth = cellSize * 0.22
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final cell = grid[r][c];
        final cx = c * cellSize + cellSize / 2;
        final cy = r * cellSize + cellSize / 2;

        if (cell.isStation) {
          _paintStation(canvas, cell.stationColor!, cx, cy);
          continue;
        }

        if (cell.isEmpty) continue;

        final paint = cell.isJunction ? juncPaint : trackPaint;
        final rail = cell.isJunction ? null : railPaint;

        // Active connection
        final activeIdx = cell.isJunction ? cell.activeIdx : 0;
        _paintConnection(canvas, cell.connections[activeIdx], cx, cy, paint, rail);

        // Junction shows inactive path dimly
        if (cell.isJunction) {
          final inactivePaint = Paint()
            ..color = const Color(0xFF2A3A5C)
            ..strokeWidth = cellSize * 0.14
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke;
          final inactiveIdx = 1 - activeIdx;
          _paintConnection(canvas, cell.connections[inactiveIdx], cx, cy, inactivePaint, null);
        }
      }
    }
  }

  void _paintConnection(
    Canvas canvas,
    ({Port a, Port b}) conn,
    double cx,
    double cy,
    Paint paint,
    Paint? rail,
  ) {
    final half = cellSize / 2;
    final p1 = _portOffset(conn.a, cx, cy, half);
    final p2 = _portOffset(conn.b, cx, cy, half);

    // Check if it's a straight line or a curve
    final isH = (conn.a == Port.left && conn.b == Port.right) ||
                (conn.a == Port.right && conn.b == Port.left);
    final isV = (conn.a == Port.top && conn.b == Port.bottom) ||
                (conn.a == Port.bottom && conn.b == Port.top);

    if (isH || isV) {
      canvas.drawLine(p1, p2, paint);
      if (rail != null) {
        // Draw parallel rails
        final perp = isH ? const Offset(0, 1) : const Offset(1, 0);
        final d = cellSize * 0.07;
        canvas.drawLine(p1 + perp * d, p2 + perp * d, rail);
        canvas.drawLine(p1 - perp * d, p2 - perp * d, rail);
        // Ties
        _drawTies(canvas, p1, p2, rail, isH, cellSize);
      }
    } else {
      // Corner curve
      _paintCurve(canvas, conn.a, conn.b, cx, cy, half, paint);
    }
  }

  void _drawTies(Canvas canvas, Offset p1, Offset p2, Paint paint, bool isH, double cellSize) {
    final tiePaint = Paint()
      ..color = paint.color.withOpacity(0.5)
      ..strokeWidth = cellSize * 0.07
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    final count = 3;
    for (int i = 1; i <= count; i++) {
      final t = i / (count + 1);
      final mid = Offset.lerp(p1, p2, t)!;
      final d = cellSize * 0.1;
      if (isH) {
        canvas.drawLine(mid - Offset(0, d), mid + Offset(0, d), tiePaint);
      } else {
        canvas.drawLine(mid - Offset(d, 0), mid + Offset(d, 0), tiePaint);
      }
    }
  }

  void _paintCurve(Canvas canvas, Port a, Port b, double cx, double cy,
      double half, Paint paint) {
    final path = Path();
    final pa = _portOffset(a, cx, cy, half);
    final pb = _portOffset(b, cx, cy, half);

    // Control point is at the corner
    final corner = _curveCorner(a, b, cx, cy, half);
    path.moveTo(pa.dx, pa.dy);
    path.quadraticBezierTo(corner.dx, corner.dy, pb.dx, pb.dy);
    canvas.drawPath(path, paint);
  }

  Offset _curveCorner(Port a, Port b, double cx, double cy, double half) {
    // Find the corner based on which two ports are involved
    if ((a == Port.top || b == Port.top) && (a == Port.right || b == Port.right)) {
      return Offset(cx + half, cy - half); // NE corner
    }
    if ((a == Port.top || b == Port.top) && (a == Port.left || b == Port.left)) {
      return Offset(cx - half, cy - half); // NW corner
    }
    if ((a == Port.bottom || b == Port.bottom) && (a == Port.right || b == Port.right)) {
      return Offset(cx + half, cy + half); // SE corner
    }
    return Offset(cx - half, cy + half); // SW corner
  }

  Offset _portOffset(Port p, double cx, double cy, double half) {
    switch (p) {
      case Port.top:    return Offset(cx, cy - half);
      case Port.bottom: return Offset(cx, cy + half);
      case Port.left:   return Offset(cx - half, cy);
      case Port.right:  return Offset(cx + half, cy);
    }
  }

  void _paintStation(Canvas canvas, TrainColor color, double cx, double cy) {
    final c = _trainColor(color);
    final r = cellSize * 0.35;

    // Glow
    final glowPaint = Paint()
      ..color = c.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(cx, cy), r * 1.5, glowPaint);

    // Station body
    final bodyPaint = Paint()..color = _kSurface;
    canvas.drawCircle(Offset(cx, cy), r, bodyPaint);

    // Station ring
    final ringPaint = Paint()
      ..color = c
      ..strokeWidth = cellSize * 0.07
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(cx, cy), r, ringPaint);

    // Inner dot
    final dotPaint = Paint()..color = c;
    canvas.drawCircle(Offset(cx, cy), r * 0.35, dotPaint);
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.grid != grid || old.cellSize != cellSize;
}

// ─────────────────────────────────────────────────────────────────────────────
// Train Widget
// ─────────────────────────────────────────────────────────────────────────────

class _TrainWidget extends StatelessWidget {
  final Color color;
  final MoveDir direction;
  final bool crashed;
  final double cellSize;

  const _TrainWidget({
    required this.color,
    required this.direction,
    required this.crashed,
    required this.cellSize,
  });

  @override
  Widget build(BuildContext context) {
    final angle = _dirAngle(direction);
    final c = crashed ? _kWrong : color;

    return Transform.rotate(
      angle: angle,
      child: CustomPaint(
        size: Size(cellSize, cellSize),
        painter: _TrainPainter(color: c, cellSize: cellSize),
      ),
    );
  }

  double _dirAngle(MoveDir d) {
    switch (d) {
      case MoveDir.right: return 0;
      case MoveDir.down:  return pi / 2;
      case MoveDir.left:  return pi;
      case MoveDir.up:    return -pi / 2;
    }
  }
}

class _TrainPainter extends CustomPainter {
  final Color color;
  final double cellSize;

  const _TrainPainter({required this.color, required this.cellSize});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Train body (pointing right)
    final bodyPaint = Paint()..color = color;
    final glowPaint = Paint()
      ..color = color.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    // Glow
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.08, h * 0.22, w * 0.82, h * 0.56),
      Radius.circular(h * 0.2),
    );
    canvas.drawRRect(bodyRect, glowPaint);

    // Body
    canvas.drawRRect(bodyRect, bodyPaint);

    // Nose (front, pointing right)
    final nosePath = Path()
      ..moveTo(w * 0.82, h * 0.22)
      ..lineTo(w * 0.96, h * 0.5)
      ..lineTo(w * 0.82, h * 0.78)
      ..close();
    canvas.drawPath(nosePath, bodyPaint);

    // Window
    final windowPaint = Paint()..color = Colors.white.withOpacity(0.85);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.5, h * 0.3, w * 0.24, h * 0.4),
        Radius.circular(h * 0.1),
      ),
      windowPaint,
    );

    // Wheels (two circles at bottom)
    final wheelPaint = Paint()..color = color.withOpacity(0.7);
    canvas.drawCircle(Offset(w * 0.25, h * 0.78), h * 0.1, wheelPaint);
    canvas.drawCircle(Offset(w * 0.65, h * 0.78), h * 0.1, wheelPaint);
  }

  @override
  bool shouldRepaint(_TrainPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Top Bar
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final int level;
  final int score;
  final int mistakes;
  final VoidCallback onBack;

  const _TopBar({
    required this.level,
    required this.score,
    required this.mistakes,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _kSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorder),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: _kText, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          // Level chip
          _Chip(
            icon: Icons.train_rounded,
            label: 'Level $level',
            color: _kAccent,
          ),
          const Spacer(),
          // Score
          _Chip(
            icon: Icons.star_rounded,
            label: '$score',
            color: _kGold,
          ),
          const SizedBox(width: 8),
          // Mistakes
          _MistakeChip(mistakes: mistakes),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _MistakeChip extends StatelessWidget {
  final int mistakes;
  const _MistakeChip({required this.mistakes});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: mistakes > 0 ? _kWrong.withOpacity(0.4) : _kBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final lit = i < mistakes;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              lit ? Icons.close_rounded : Icons.circle,
              color: lit ? _kWrong : _kMuted.withOpacity(0.4),
              size: lit ? 14 : 8,
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Idle Overlay
// ─────────────────────────────────────────────────────────────────────────────

class _IdleOverlay extends StatelessWidget {
  final int level;
  final AnimationController idleAnim;
  final VoidCallback onStart;

  const _IdleOverlay({
    required this.level,
    required this.idleAnim,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: _kBg.withOpacity(0.85),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _kBorder, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: _kAccent.withOpacity(0.15),
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                AnimatedBuilder(
                  animation: idleAnim,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, -6 * idleAnim.value),
                    child: child,
                  ),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: _kAccent.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: _kAccent.withOpacity(0.4), width: 1.5),
                    ),
                    child: const Icon(Icons.train_rounded, color: _kAccent, size: 36),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Train of Thought',
                  style: const TextStyle(
                    color: _kText,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                if (level > 1) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Level $level',
                    style: const TextStyle(color: _kAccent, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 16),
                const _InstructionRow(icon: Icons.touch_app_rounded, text: 'Tap junctions to switch tracks'),
                const SizedBox(height: 8),
                const _InstructionRow(icon: Icons.train_rounded, text: 'Route each train to its matching station'),
                const SizedBox(height: 8),
                const _InstructionRow(icon: Icons.cancel_rounded, text: '3 mistakes = game over'),
                const SizedBox(height: 24),
                _StartButton(onTap: onStart, label: level == 1 ? 'Start Game' : 'Start Level $level'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InstructionRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InstructionRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _kAccent, size: 16),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: _kMuted, fontSize: 13)),
      ],
    );
  }
}

class _StartButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  const _StartButton({required this.onTap, required this.label});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4A7AEF), Color(0xFF7B5FFF)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _kAccent.withOpacity(0.35),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Level Complete Overlay
// ─────────────────────────────────────────────────────────────────────────────

class _LevelCompleteOverlay extends StatelessWidget {
  final int level;
  final int score;
  final int stars;
  final AnimationController winAnim;
  final VoidCallback onNext;

  const _LevelCompleteOverlay({
    required this.level,
    required this.score,
    required this.stars,
    required this.winAnim,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: _kBg.withOpacity(0.88),
        child: Center(
          child: AnimatedBuilder(
            animation: winAnim,
            builder: (_, child) => Transform.scale(
              scale: 0.85 + 0.15 * CurvedAnimation(
                parent: winAnim,
                curve: Curves.elasticOut,
              ).value,
              child: child,
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: _kSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _kGold.withOpacity(0.4), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: _kGold.withOpacity(0.15),
                    blurRadius: 40,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events_rounded,
                      color: _kGold, size: 52),
                  const SizedBox(height: 12),
                  const Text('Level Complete!',
                      style: TextStyle(
                          color: _kText,
                          fontSize: 22,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  // Stars
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      final lit = i < stars;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          lit ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: lit ? _kGold : _kMuted,
                          size: 36,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  _StatRow(label: 'Score', value: '$score', color: _kGold),
                  const SizedBox(height: 24),
                  _StartButton(
                      onTap: onNext,
                      label: 'Level ${level + 1}'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Game Over Overlay
// ─────────────────────────────────────────────────────────────────────────────

class _GameOverOverlay extends StatelessWidget {
  final int score;
  final int level;
  final VoidCallback onRetry;

  const _GameOverOverlay({
    required this.score,
    required this.level,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: _kBg.withOpacity(0.88),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _kWrong.withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: _kWrong.withOpacity(0.12),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.close_rounded, color: _kWrong, size: 52),
                const SizedBox(height: 12),
                const Text('Game Over',
                    style: TextStyle(
                        color: _kText,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                _StatRow(label: 'Final Score', value: '$score', color: _kAccent),
                const SizedBox(height: 6),
                _StatRow(label: 'Level Reached', value: '$level', color: _kMuted),
                const SizedBox(height: 24),
                _StartButton(onTap: onRetry, label: 'Try Again'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat Row
// ─────────────────────────────────────────────────────────────────────────────

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: _kMuted, fontSize: 13)),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
