import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../features/home/providers/user_provider.dart';
import '../../services/game_service.dart';
import '../models/train_of_thought_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Visual constants – Lumosity palette
// ─────────────────────────────────────────────────────────────────────────────

const _kBoardGreen      = Color(0xFF2E7D32); // deep forest green
const _kBoardGreenLight = Color(0xFF388E3C); // subtle variation for checkerboard
const _kTrackBed        = Color(0xFF1B5E20); // very dark green track bed
const _kTrackRail       = Color(0xFF4CAF50); // bright rail lines
const _kJunctionFill    = Color(0xFF66BB6A); // junction circle fill
const _kJunctionBorder  = Color(0xFFA5D6A7); // junction circle border
const _kJunctionGlow    = Color(0xFF81C784); // active path highlight inside junction
const _kHeaderBg        = Color(0xFFEEEEEE); // light grey header (Lumosity style)
const _kHeaderDivider   = Color(0xFFBDBDBD);
const _kHeaderText      = Color(0xFF212121);
const _kHeaderLabel     = Color(0xFF757575);

/// Per-color accent palette for trains and station buildings
Color _trainAccent(TrainColor c) {
  switch (c) {
    case TrainColor.blue:   return const Color(0xFF1E88E5);
    case TrainColor.pink:   return const Color(0xFFE91E8C);
    case TrainColor.red:    return const Color(0xFFE53935);
    case TrainColor.green:  return const Color(0xFF43A047);
    case TrainColor.yellow: return const Color(0xFFFDD835);
    case TrainColor.white:  return const Color(0xFFECEFF1);
    case TrainColor.purple: return const Color(0xFF8E24AA);
  }
}

/// Slightly darker shade for building walls / train body
Color _trainDark(TrainColor c) {
  switch (c) {
    case TrainColor.blue:   return const Color(0xFF1565C0);
    case TrainColor.pink:   return const Color(0xFFC2185B);
    case TrainColor.red:    return const Color(0xFFB71C1C);
    case TrainColor.green:  return const Color(0xFF2E7D32);
    case TrainColor.yellow: return const Color(0xFFF9A825);
    case TrainColor.white:  return const Color(0xFF90A4AE);
    case TrainColor.purple: return const Color(0xFF6A1B9A);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page root
// ─────────────────────────────────────────────────────────────────────────────

class TrainOfThoughtPage extends StatefulWidget {
  const TrainOfThoughtPage({super.key});

  @override
  State<TrainOfThoughtPage> createState() => _TrainOfThoughtPageState();
}

class _TrainOfThoughtPageState extends State<TrainOfThoughtPage>
    with TickerProviderStateMixin {

  // ── Game state ──────────────────────────────────────────────────────────────
  late TrainOfThoughtState _game;
  bool _gameInitialized = false;
  Timer? _tickTimer;

  // Countdown timer (Lumosity counts down from a fixed duration)
  static const int _gameDurationSec = 120; // 2 minutes per session
  int _timeRemaining = _gameDurationSec;
  Timer? _countdownTimer;
  int _startTimeEpoch = 0;

  // ── Animation controllers ───────────────────────────────────────────────────
  /// Smooth interpolated positions for each train (col as dx, row as dy)
  final Map<int, Offset> _trainAnimPos = {};
  final Map<int, AnimationController> _trainMoveAnims = {};

  late AnimationController _idleFloatAnim;
  late AnimationController _wrongFlashAnim;
  late AnimationController _winAnim;

  // ── Junction flash: map junctionKey→opacity ────────────────────────────────
  final Map<String, AnimationController> _junctionFlash = {};

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _idleFloatAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _wrongFlashAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _winAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _loadLevel(1);
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _countdownTimer?.cancel();
    _idleFloatAnim.dispose();
    _wrongFlashAnim.dispose();
    _winAnim.dispose();
    for (final c in _trainMoveAnims.values) c.dispose();
    for (final c in _junctionFlash.values) c.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Level management
  // ─────────────────────────────────────────────────────────────────────────

  void _loadLevel(int level, {bool resetTimer = false}) {
    _tickTimer?.cancel();
    _countdownTimer?.cancel();

    if (resetTimer) _timeRemaining = _gameDurationSec;

    // Dispose old animation controllers
    for (final c in _trainMoveAnims.values) c.dispose();
    _trainMoveAnims.clear();
    _trainAnimPos.clear();
    for (final c in _junctionFlash.values) c.dispose();
    _junctionFlash.clear();

    final def = LevelFactory.buildLevel(level);

    // Create per-train animation controllers
    for (int i = 0; i < def.trains.length; i++) {
      _trainMoveAnims[i] = AnimationController(
        vsync: this,
        duration: def.tickInterval * 0.85,
      );
      _trainAnimPos[i] = Offset(
        def.trains[i].col.toDouble(),
        def.trains[i].row.toDouble(),
      );
    }

    // Create per-junction flash controllers
    for (int r = 0; r < def.rows; r++) {
      for (int c = 0; c < def.cols; c++) {
        if (def.grid[r][c].isJunction) {
          final key = '$r-$c';
          _junctionFlash[key] = AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 220),
          );
        }
      }
    }

    final carryCorrect  = _gameInitialized ? _game.correct   : 0;
    final carryTotal    = _gameInitialized ? _game.total     : 0;
    final carryMistakes = _gameInitialized ? _game.mistakes  : 0;

    final newState = TrainOfThoughtState(
      level: level,
      correct:  resetTimer ? 0 : carryCorrect,
      total:    resetTimer ? 0 : carryTotal,
      mistakes: resetTimer ? 0 : carryMistakes,
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
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _game.phase != GamePhase.playing) return;
      setState(() { _timeRemaining = (_timeRemaining - 1).clamp(0, _gameDurationSec); });
      if (_timeRemaining <= 0) {
        _countdownTimer?.cancel();
        _tickTimer?.cancel();
        setState(() {
          _game = _game.copyWith(phase: GamePhase.gameOver);
        });
        _submitResult(completed: false);
      }
    });
  }

  void _scheduleTick() {
    _tickTimer?.cancel();
    _tickTimer = Timer(_game.tickInterval, _onTick);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Game tick – moves all trains one cell
  // ─────────────────────────────────────────────────────────────────────────

  void _onTick() {
    if (_game.phase != GamePhase.playing) return;

    final grid   = _game.grid;
    final trains = List<Train>.from(_game.trains);
    int correct  = _game.correct;
    int total    = _game.total;
    int mistakes = _game.mistakes;

    for (int i = 0; i < trains.length; i++) {
      final t = trains[i];
      if (!t.alive) continue;

      final nextRow = t.row + t.direction.dRow;
      final nextCol = t.col + t.direction.dCol;

      // Out of bounds → derail
      if (nextRow < 0 || nextRow >= _game.rows ||
          nextCol < 0 || nextCol >= _game.cols) {
        trains[i] = t.copyWith(alive: false, crashed: true);
        mistakes++;
        total++;
        HapticFeedback.heavyImpact();
        _wrongFlashAnim.forward(from: 0);
        continue;
      }

      final nextCell = grid[nextRow][nextCol];

      // ── Station ──────────────────────────────────────────────────────────
      if (nextCell.isStation) {
        _startTrainMoveAnim(i, nextRow.toDouble(), nextCol.toDouble());
        total++;
        if (nextCell.stationColor == t.color) {
          // Correct!
          trains[i] = t.copyWith(row: nextRow, col: nextCol, alive: false, arrived: true);
          correct++;
          HapticFeedback.selectionClick();
        } else {
          // Wrong station
          trains[i] = t.copyWith(row: nextRow, col: nextCol, alive: false, crashed: true);
          mistakes++;
          HapticFeedback.heavyImpact();
          _wrongFlashAnim.forward(from: 0);
        }
        continue;
      }

      // ── Empty / off-track → derail ────────────────────────────────────────
      if (nextCell.isEmpty) {
        trains[i] = t.copyWith(alive: false, crashed: true);
        mistakes++;
        total++;
        HapticFeedback.heavyImpact();
        _wrongFlashAnim.forward(from: 0);
        continue;
      }

      // ── Regular track / junction ──────────────────────────────────────────
      final entryPort = t.direction.entryPort;
      final exitPort  = nextCell.exitPort(entryPort);

      if (exitPort == null) {
        // Can't route → derail
        trains[i] = t.copyWith(alive: false, crashed: true);
        mistakes++;
        total++;
        HapticFeedback.heavyImpact();
        _wrongFlashAnim.forward(from: 0);
        continue;
      }

      final newDir = exitPort.exitDir;
      trains[i] = t.copyWith(row: nextRow, col: nextCol, direction: newDir);
      _startTrainMoveAnim(i, nextRow.toDouble(), nextCol.toDouble());
    }

    // ── Level complete? ───────────────────────────────────────────────────────
    final allDone = trains.every((t) => !t.alive);
    if (allDone) {
      _tickTimer?.cancel();
      _countdownTimer?.cancel();
      setState(() {
        _game = _game.copyWith(
          trains: trains,
          correct: correct,
          total: total,
          mistakes: mistakes,
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
        correct: correct,
        total: total,
        mistakes: mistakes,
      );
    });
    _scheduleTick();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Smooth train movement animation
  // ─────────────────────────────────────────────────────────────────────────

  void _startTrainMoveAnim(int idx, double toRow, double toCol) {
    final ctrl = _trainMoveAnims[idx];
    if (ctrl == null) return;
    final from = _trainAnimPos[idx] ?? Offset(toCol, toRow);
    final to   = Offset(toCol, toRow);

    ctrl.stop();
    ctrl.reset();

    final anim = Tween<Offset>(begin: from, end: to).animate(
      CurvedAnimation(parent: ctrl, curve: Curves.easeInOut),
    );
    anim.addListener(() {
      if (mounted) setState(() { _trainAnimPos[idx] = anim.value; });
    });
    ctrl.forward();
    _trainAnimPos[idx] = to;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Junction tap
  // ─────────────────────────────────────────────────────────────────────────

  void _onJunctionTap(int row, int col) {
    if (_game.phase != GamePhase.playing) return;
    final cell = _game.grid[row][col];
    if (!cell.isJunction) return;

    HapticFeedback.selectionClick();

    // Flash animation
    final key = '$row-$col';
    _junctionFlash[key]?.forward(from: 0);

    final newGrid = _game.grid.map((r) => List<TrackCell>.from(r)).toList();
    newGrid[row][col] = cell.copyWith(activeIdx: 1 - cell.activeIdx);
    setState(() { _game = _game.copyWith(grid: newGrid); });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Backend submission
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _submitResult({required bool completed}) async {
    final elapsed =
        (DateTime.now().millisecondsSinceEpoch - _startTimeEpoch) ~/ 1000;
    final result = await GameService.submitResult(
      gameType: 'train_of_thought',
      score: _game.correct * 100,
      timePlayedSeconds: elapsed,
      completed: completed,
      levelReached: _game.level,
      mistakes: _game.mistakes,
    );
    if (result != null && mounted) {
      context.read<UserProvider>().updateFocusScore(result.newFocusScore);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBoardGreen,
      body: SafeArea(
        child: Column(
          children: [
            // Lumosity-style light header bar
            _LumosityHeader(
              timeRemaining: _timeRemaining,
              correct: _game.correct,
              total: _game.total,
              onBack: () => Navigator.of(context).pop(),
            ),
            // Green game board
            Expanded(
              child: Stack(
                children: [
                  _buildGameBoard(),
                  // Overlays
                  if (_game.phase == GamePhase.idle)
                    _IdleOverlay(
                      level: _game.level,
                      floatAnim: _idleFloatAnim,
                      onStart: _startGame,
                    ),
                  if (_game.phase == GamePhase.levelComplete)
                    _LevelCompleteOverlay(
                      level: _game.level,
                      correct: _game.correct,
                      total: _game.total,
                      stars: _game.stars,
                      winAnim: _winAnim,
                      onNext: () {
                        _winAnim.reset();
                        _loadLevel(_game.level + 1);
                        Future.delayed(
                          const Duration(milliseconds: 150), _startGame);
                      },
                    ),
                  if (_game.phase == GamePhase.gameOver)
                    _GameOverOverlay(
                      correct: _game.correct,
                      total: _game.total,
                      level: _game.level,
                      onRetry: () {
                        _timeRemaining = _gameDurationSec;
                        _loadLevel(_game.level, resetTimer: true);
                        Future.delayed(
                          const Duration(milliseconds: 150), _startGame);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Game board layout
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildGameBoard() {
    return LayoutBuilder(builder: (context, constraints) {
      const padding = 14.0;
      final availW = constraints.maxWidth  - padding * 2;
      final availH = constraints.maxHeight - padding * 2;
      final cellW  = availW / _game.cols;
      final cellH  = availH / _game.rows;
      final cellSize = min(cellW, cellH).clamp(20.0, 68.0);
      final gridW  = cellSize * _game.cols;
      final gridH  = cellSize * _game.rows;

      return Center(
        child: SizedBox(
          width: gridW,
          height: gridH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 1 – track + station layer (CustomPaint)
              CustomPaint(
                size: Size(gridW, gridH),
                painter: _TrackPainter(
                  grid: _game.grid,
                  rows: _game.rows,
                  cols: _game.cols,
                  cellSize: cellSize,
                  junctionFlash: _junctionFlash,
                ),
              ),
              // 2 – interactive junction tap targets
              ..._junctionTargets(cellSize),
              // 3 – trains
              ..._trainWidgets(cellSize),
            ],
          ),
        ),
      );
    });
  }

  List<Widget> _junctionTargets(double cs) {
    final out = <Widget>[];
    for (int r = 0; r < _game.rows; r++) {
      for (int c = 0; c < _game.cols; c++) {
        if (!_game.grid[r][c].isJunction) continue;
        out.add(Positioned(
          left:   c * cs - cs * 0.15,
          top:    r * cs - cs * 0.15,
          width:  cs * 1.3,
          height: cs * 1.3,
          child: GestureDetector(
            onTap: () => _onJunctionTap(r, c),
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ));
      }
    }
    return out;
  }

  List<Widget> _trainWidgets(double cs) {
    final out = <Widget>[];
    for (int i = 0; i < _game.trains.length; i++) {
      final t       = _game.trains[i];
      final animPos = _trainAnimPos[i] ?? Offset(t.col.toDouble(), t.row.toDouble());

      double opacity;
      if (!t.alive) {
        opacity = t.arrived ? 0.0 : (t.crashed ? 0.5 : 0.0);
      } else {
        opacity = 1.0;
      }

      final size = cs * 0.72;
      out.add(Positioned(
        left: animPos.dx * cs + (cs - size) / 2,
        top:  animPos.dy * cs + (cs - size) / 2,
        width:  size,
        height: size,
        child: AnimatedOpacity(
          opacity: opacity,
          duration: const Duration(milliseconds: 280),
          child: _TrainWidget(
            color:    t.color,
            direction: t.direction,
            crashed:  t.crashed,
            size:     size,
          ),
        ),
      ));
    }
    return out;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Track Painter – draws the entire board in Lumosity style
// ─────────────────────────────────────────────────────────────────────────────

class _TrackPainter extends CustomPainter {
  final List<List<TrackCell>> grid;
  final int rows;
  final int cols;
  final double cellSize;
  final Map<String, AnimationController> junctionFlash;

  const _TrackPainter({
    required this.grid,
    required this.rows,
    required this.cols,
    required this.cellSize,
    required this.junctionFlash,
  });

  // ── Helpers ────────────────────────────────────────────────────────────────

  Offset _portPt(Port p, double cx, double cy) {
    final h = cellSize / 2;
    switch (p) {
      case Port.top:    return Offset(cx, cy - h);
      case Port.bottom: return Offset(cx, cy + h);
      case Port.left:   return Offset(cx - h, cy);
      case Port.right:  return Offset(cx + h, cy);
    }
  }

  bool _isStraight(Port a, Port b) {
    return (a == Port.left  && b == Port.right)  ||
           (a == Port.right && b == Port.left)   ||
           (a == Port.top   && b == Port.bottom) ||
           (a == Port.bottom && b == Port.top);
  }

  // ── Main paint ─────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);

    // First pass: draw all regular (non-junction) tracks
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final cell = grid[r][c];
        final cx   = c * cellSize + cellSize / 2;
        final cy   = r * cellSize + cellSize / 2;

        if (cell.isEmpty || cell.isJunction || cell.isStation) continue;
        _drawTrack(canvas, cell.connections[0], cx, cy, bright: false);
      }
    }

    // Second pass: junctions (drawn on top so circles sit above tracks)
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final cell = grid[r][c];
        if (!cell.isJunction) continue;
        final cx = c * cellSize + cellSize / 2;
        final cy = r * cellSize + cellSize / 2;
        final key = '$r-$c';
        final flash = junctionFlash[key]?.value ?? 0.0;
        _drawJunction(canvas, cell, cx, cy, flashT: flash);
      }
    }

    // Third pass: station buildings (topmost layer)
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final cell = grid[r][c];
        if (!cell.isStation) continue;
        final cx = c * cellSize + cellSize / 2;
        final cy = r * cellSize + cellSize / 2;
        _drawStationBuilding(canvas, cell.stationColor!, cx, cy);
      }
    }
  }

  // ── Background ─────────────────────────────────────────────────────────────

  void _drawBackground(Canvas canvas, Size size) {
    // Solid deep green base
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = _kBoardGreen,
    );

    // Very subtle grid texture (every-other-cell lighter shade)
    final lightPaint = Paint()..color = _kBoardGreenLight.withOpacity(0.18);
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if ((r + c) % 2 == 0) {
          canvas.drawRect(
            Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize),
            lightPaint,
          );
        }
      }
    }

    // Small tree decorations in board corners
    _drawTree(canvas, cellSize * 0.4, cellSize * 0.4);
    _drawTree(canvas, size.width - cellSize * 0.4, cellSize * 0.4);
    _drawTree(canvas, cellSize * 0.4, size.height - cellSize * 0.4);
    _drawTree(canvas, size.width - cellSize * 0.4, size.height - cellSize * 0.4);
  }

  void _drawTree(Canvas canvas, double x, double y) {
    final r = cellSize * 0.22;
    // Trunk
    canvas.drawRect(
      Rect.fromLTWH(x - r * 0.18, y + r * 0.5, r * 0.36, r * 0.7),
      Paint()..color = const Color(0xFF4E342E).withOpacity(0.55),
    );
    // Canopy (two layered triangles)
    final canopy = Paint()..color = const Color(0xFF1B5E20).withOpacity(0.7);
    final path = Path()
      ..moveTo(x, y - r)
      ..lineTo(x + r * 1.1, y + r * 0.6)
      ..lineTo(x - r * 1.1, y + r * 0.6)
      ..close();
    canvas.drawPath(path, canopy);
    final path2 = Path()
      ..moveTo(x, y - r * 1.5)
      ..lineTo(x + r * 0.8, y)
      ..lineTo(x - r * 0.8, y)
      ..close();
    canvas.drawPath(path2, canopy..color = const Color(0xFF2E7D32).withOpacity(0.75));
  }

  // ── Track segment ──────────────────────────────────────────────────────────

  void _drawTrack(Canvas canvas, ({Port a, Port b}) conn,
      double cx, double cy, {required bool bright}) {
    final half  = cellSize / 2;
    final width = cellSize * 0.26;

    final bedPaint = Paint()
      ..color  = bright ? _kTrackRail.withOpacity(0.55) : _kTrackBed
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final p1 = _portPt(conn.a, cx, cy);
    final p2 = _portPt(conn.b, cx, cy);

    if (_isStraight(conn.a, conn.b)) {
      canvas.drawLine(p1, p2, bedPaint);
      _drawRails(canvas, p1, p2, conn.a, cx, cy);
    } else {
      _drawCurve(canvas, conn.a, conn.b, cx, cy, half, bedPaint);
    }
  }

  void _drawRails(Canvas canvas, Offset p1, Offset p2, Port a,
      double cx, double cy) {
    final isH = (a == Port.left || a == Port.right);
    final d   = cellSize * 0.065;
    final perp = isH ? const Offset(0, 1) : const Offset(1, 0);

    final railPaint = Paint()
      ..color = _kTrackRail.withOpacity(0.50)
      ..strokeWidth = cellSize * 0.045
      ..strokeCap = StrokeCap.butt
      ..style = PaintingStyle.stroke;

    canvas.drawLine(p1 + perp * d, p2 + perp * d, railPaint);
    canvas.drawLine(p1 - perp * d, p2 - perp * d, railPaint);

    // Crossties
    final tiePaint = Paint()
      ..color = _kTrackRail.withOpacity(0.3)
      ..strokeWidth = cellSize * 0.055
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    for (int i = 1; i <= 3; i++) {
      final t   = i / 4.0;
      final mid = Offset.lerp(p1, p2, t)!;
      final td  = cellSize * 0.09;
      if (isH) {
        canvas.drawLine(mid - Offset(0, td), mid + Offset(0, td), tiePaint);
      } else {
        canvas.drawLine(mid - Offset(td, 0), mid + Offset(td, 0), tiePaint);
      }
    }
  }

  void _drawCurve(Canvas canvas, Port a, Port b,
      double cx, double cy, double half, Paint paint) {
    final p1 = _portPt(a, cx, cy);
    final p2 = _portPt(b, cx, cy);
    final corner = _curveCorner(a, b, cx, cy, half);
    final path = Path()
      ..moveTo(p1.dx, p1.dy)
      ..quadraticBezierTo(corner.dx, corner.dy, p2.dx, p2.dy);
    canvas.drawPath(path, paint);
  }

  Offset _curveCorner(Port a, Port b, double cx, double cy, double half) {
    final ports = {a, b};
    if (ports.contains(Port.top) && ports.contains(Port.right))  return Offset(cx + half, cy - half);
    if (ports.contains(Port.top) && ports.contains(Port.left))   return Offset(cx - half, cy - half);
    if (ports.contains(Port.bottom) && ports.contains(Port.right)) return Offset(cx + half, cy + half);
    return Offset(cx - half, cy + half);
  }

  // ── Junction ───────────────────────────────────────────────────────────────

  void _drawJunction(Canvas canvas, TrackCell cell,
      double cx, double cy, {required double flashT}) {
    // Draw inactive path dim
    final inactive = 1 - cell.activeIdx;
    _drawTrack(canvas, cell.connections[inactive], cx, cy, bright: false);
    // Draw active path bright
    _drawTrack(canvas, cell.connections[cell.activeIdx], cx, cy, bright: true);

    // Central circular node
    final radius = cellSize * 0.33;
    final glowR  = radius + cellSize * 0.06 * (1 + flashT);

    // Outer glow on tap
    if (flashT > 0) {
      canvas.drawCircle(
        Offset(cx, cy), glowR,
        Paint()
          ..color = Colors.white.withOpacity(0.55 * flashT)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    // Shadow beneath circle
    canvas.drawCircle(
      Offset(cx, cy + 2), radius + 2,
      Paint()..color = Colors.black26,
    );

    // Fill
    final fillColor = Color.lerp(_kJunctionFill, Colors.white, flashT * 0.5)!;
    canvas.drawCircle(
      Offset(cx, cy), radius,
      Paint()..color = fillColor,
    );

    // Border
    canvas.drawCircle(
      Offset(cx, cy), radius,
      Paint()
        ..color = _kJunctionBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = cellSize * 0.05,
    );

    // Active direction indicator – small bright dot/arrow inside circle
    _drawActiveIndicator(canvas, cell, cx, cy, radius);
  }

  void _drawActiveIndicator(Canvas canvas, TrackCell cell,
      double cx, double cy, double radius) {
    final conn = cell.connections[cell.activeIdx];
    final isH  = _isStraight(conn.a, conn.b) &&
                 (conn.a == Port.left || conn.a == Port.right);
    final isV  = _isStraight(conn.a, conn.b) &&
                 (conn.a == Port.top || conn.a == Port.bottom);

    final dotPaint = Paint()..color = Colors.white.withOpacity(0.85);
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.75)
      ..strokeWidth = cellSize * 0.055
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (isH) {
      // horizontal arrow ←→
      canvas.drawLine(
        Offset(cx - radius * 0.55, cy),
        Offset(cx + radius * 0.55, cy),
        linePaint,
      );
    } else if (isV) {
      // vertical arrow ↑↓
      canvas.drawLine(
        Offset(cx, cy - radius * 0.55),
        Offset(cx, cy + radius * 0.55),
        linePaint,
      );
    } else {
      // diagonal curve – just a dot
      canvas.drawCircle(Offset(cx, cy), radius * 0.2, dotPaint);
    }
  }

  // ── Station building ────────────────────────────────────────────────────────

  void _drawStationBuilding(Canvas canvas, TrainColor color,
      double cx, double cy) {
    final accent = _trainAccent(color);
    final dark   = _trainDark(color);

    final bw = cellSize * 0.75;  // building width
    final bh = cellSize * 0.55;  // building body height
    final rh = cellSize * 0.30;  // roof height

    final left   = cx - bw / 2;
    final right  = cx + bw / 2;
    final bottom = cy + bh / 2 + rh * 0.15;
    final bodyTop = bottom - bh;
    final roofTop = bodyTop - rh;

    // Drop shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(left + 2, bodyTop + 3, right + 2, bottom + 3),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.black.withOpacity(0.30),
    );

    // Building body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(left, bodyTop, right, bottom),
        const Radius.circular(3),
      ),
      Paint()..color = accent,
    );

    // Body highlight (lighter left strip)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(left, bodyTop, left + bw * 0.18, bottom),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.white.withOpacity(0.20),
    );

    // Body outline
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(left, bodyTop, right, bottom),
        const Radius.circular(3),
      ),
      Paint()
        ..color = dark
        ..style = PaintingStyle.stroke
        ..strokeWidth = cellSize * 0.04,
    );

    // Roof (pentagon / house shape)
    final roofPath = Path()
      ..moveTo(left  - bw * 0.06, bodyTop)
      ..lineTo(right + bw * 0.06, bodyTop)
      ..lineTo(right + bw * 0.06, roofTop + rh * 0.45)
      ..lineTo(cx,   roofTop)
      ..lineTo(left  - bw * 0.06, roofTop + rh * 0.45)
      ..close();
    canvas.drawPath(roofPath, Paint()..color = dark);

    // Roof highlight
    canvas.drawPath(
      roofPath,
      Paint()
        ..color = Colors.white.withOpacity(0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cellSize * 0.025,
    );

    // Door (centered at bottom)
    final doorW = bw * 0.24;
    final doorH = bh * 0.42;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          cx - doorW / 2, bottom - doorH,
          cx + doorW / 2, bottom,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = dark.withOpacity(0.75),
    );

    // Two windows
    final winW = bw * 0.20;
    final winH = bh * 0.28;
    final winTop = bodyTop + bh * 0.15;
    for (final xOff in [-bw * 0.25, bw * 0.25]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            cx + xOff - winW / 2, winTop,
            cx + xOff + winW / 2, winTop + winH,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = Colors.white.withOpacity(0.80),
      );
      // Window cross
      final crossPaint = Paint()
        ..color = dark.withOpacity(0.35)
        ..strokeWidth = cellSize * 0.025;
      canvas.drawLine(
        Offset(cx + xOff, winTop),
        Offset(cx + xOff, winTop + winH),
        crossPaint,
      );
      canvas.drawLine(
        Offset(cx + xOff - winW / 2, winTop + winH / 2),
        Offset(cx + xOff + winW / 2, winTop + winH / 2),
        crossPaint,
      );
    }

    // Star / flag on rooftop
    _drawStar(canvas, cx, roofTop - cellSize * 0.06, cellSize * 0.09, accent);
  }

  void _drawStar(Canvas canvas, double cx, double cy,
      double r, Color color) {
    final paint = Paint()..color = Colors.white;
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final outerAngle = -pi / 2 + 2 * pi * i / 5;
      final innerAngle = outerAngle + pi / 5;
      final op = Offset(
          cx + r * cos(outerAngle), cy + r * sin(outerAngle));
      final ip = Offset(
          cx + r * 0.45 * cos(innerAngle), cy + r * 0.45 * sin(innerAngle));
      if (i == 0) path.moveTo(op.dx, op.dy);
      else path.lineTo(op.dx, op.dy);
      path.lineTo(ip.dx, ip.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrackPainter old) => true; // repaint on every frame for flash anims
}

// ─────────────────────────────────────────────────────────────────────────────
// Train Widget – cute pixel-style train car
// ─────────────────────────────────────────────────────────────────────────────

class _TrainWidget extends StatelessWidget {
  final TrainColor color;
  final MoveDir direction;
  final bool crashed;
  final double size;

  const _TrainWidget({
    required this.color,
    required this.direction,
    required this.crashed,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final angle = _angle(direction);
    return Transform.rotate(
      angle: angle,
      child: CustomPaint(
        size: Size(size, size),
        painter: _TrainPainter(
          color:   crashed ? const Color(0xFFEF5350) : _trainAccent(color),
          dark:    crashed ? const Color(0xFFB71C1C)  : _trainDark(color),
          crashed: crashed,
        ),
      ),
    );
  }

  double _angle(MoveDir d) {
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
  final Color dark;
  final bool crashed;
  const _TrainPainter({required this.color, required this.dark, required this.crashed});

  @override
  void paint(Canvas canvas, Size sz) {
    final w = sz.width;
    final h = sz.height;

    // Glow / drop shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.08, h * 0.22, w * 0.82, h * 0.56),
        Radius.circular(h * 0.18),
      ),
      Paint()
        ..color = color.withOpacity(0.50)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Body (pointing RIGHT)
    final bodyRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.08, h * 0.22, w * 0.72, h * 0.56),
      Radius.circular(h * 0.18),
    );
    canvas.drawRRect(bodyRRect, Paint()..color = color);

    // Body shading top highlight
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.10, h * 0.24, w * 0.68, h * 0.20),
        Radius.circular(h * 0.12),
      ),
      Paint()..color = Colors.white.withOpacity(0.30),
    );

    // Cab / nose on the RIGHT side
    final cabPath = Path()
      ..moveTo(w * 0.80, h * 0.22)
      ..lineTo(w * 0.96, h * 0.50)
      ..lineTo(w * 0.80, h * 0.78)
      ..close();
    canvas.drawPath(cabPath, Paint()..color = dark);

    // Window
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.48, h * 0.30, w * 0.24, h * 0.38),
        Radius.circular(h * 0.08),
      ),
      Paint()..color = Colors.white.withOpacity(0.85),
    );

    // Body outline
    canvas.drawRRect(
      bodyRRect,
      Paint()
        ..color = dark
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.06,
    );

    // Wheels (left and right)
    final wheelPaint = Paint()..color = dark;
    final wheelR = h * 0.10;
    canvas.drawCircle(Offset(w * 0.22, h * 0.80), wheelR, wheelPaint);
    canvas.drawCircle(Offset(w * 0.60, h * 0.80), wheelR, wheelPaint);

    final wheelRimPaint = Paint()
      ..color = Colors.white.withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = wheelR * 0.35;
    canvas.drawCircle(Offset(w * 0.22, h * 0.80), wheelR * 0.6, wheelRimPaint);
    canvas.drawCircle(Offset(w * 0.60, h * 0.80), wheelR * 0.6, wheelRimPaint);

    // X mark on crashed train
    if (crashed) {
      final xPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = h * 0.08
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(w * 0.22, h * 0.30), Offset(w * 0.50, h * 0.70), xPaint);
      canvas.drawLine(
        Offset(w * 0.50, h * 0.30), Offset(w * 0.22, h * 0.70), xPaint);
    }
  }

  @override
  bool shouldRepaint(_TrainPainter old) =>
      old.color != color || old.crashed != crashed;
}

// ─────────────────────────────────────────────────────────────────────────────
// Lumosity-style Header
// ─────────────────────────────────────────────────────────────────────────────

class _LumosityHeader extends StatelessWidget {
  final int timeRemaining;
  final int correct;
  final int total;
  final VoidCallback onBack;

  const _LumosityHeader({
    required this.timeRemaining,
    required this.correct,
    required this.total,
    required this.onBack,
  });

  String get _timeStr {
    final m = timeRemaining ~/ 60;
    final s = timeRemaining % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isLow = timeRemaining <= 20;
    return Container(
      color: _kHeaderBg,
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: onBack,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: _kHeaderText, size: 18),
            ),
          ),
          Container(width: 1, height: 36, color: _kHeaderDivider),
          // TIME
          Expanded(
            child: _HeaderCell(
              label: 'TIME',
              value: _timeStr,
              valueColor: isLow ? const Color(0xFFE53935) : _kHeaderText,
              bold: isLow,
            ),
          ),
          Container(width: 1, height: 36, color: _kHeaderDivider),
          // CORRECT
          Expanded(
            child: _HeaderCell(
              label: 'CORRECT',
              value: '$correct of $total',
              valueColor: _kHeaderText,
              bold: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final bool bold;
  const _HeaderCell({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.bold,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                color: _kHeaderLabel,
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              )),
          const SizedBox(height: 1),
          Text(value,
              style: TextStyle(
                color: valueColor,
                fontSize: 15,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
              )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overlays
// ─────────────────────────────────────────────────────────────────────────────

class _IdleOverlay extends StatelessWidget {
  final int level;
  final AnimationController floatAnim;
  final VoidCallback onStart;

  const _IdleOverlay({
    required this.level,
    required this.floatAnim,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: _kHeaderBg,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 24, offset: Offset(0, 6)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: floatAnim,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, -5 * floatAnim.value),
                    child: child,
                  ),
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: _kJunctionFill,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _kJunctionFill.withOpacity(0.4),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.train_rounded,
                        color: Colors.white, size: 38),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  level == 1 ? 'Train of Thought' : 'Level $level',
                  style: const TextStyle(
                    color: _kHeaderText,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                if (level == 1)
                  Text(
                    'Route trains to matching stations',
                    style: TextStyle(color: _kHeaderLabel, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 18),
                const _HowToRow(
                  icon: Icons.touch_app_rounded,
                  text: 'Tap junctions to switch tracks',
                ),
                const SizedBox(height: 8),
                const _HowToRow(
                  icon: Icons.compare_arrows_rounded,
                  text: 'Match each train to its station',
                ),
                const SizedBox(height: 24),
                _GreenButton(
                  label: level == 1 ? 'Start Game' : 'Start Level $level',
                  onTap: onStart,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HowToRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HowToRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _kJunctionFill, size: 16),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: _kHeaderLabel, fontSize: 13)),
      ],
    );
  }
}

class _LevelCompleteOverlay extends StatelessWidget {
  final int level;
  final int correct;
  final int total;
  final int stars;
  final AnimationController winAnim;
  final VoidCallback onNext;

  const _LevelCompleteOverlay({
    required this.level,
    required this.correct,
    required this.total,
    required this.stars,
    required this.winAnim,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: AnimatedBuilder(
            animation: winAnim,
            builder: (_, child) => Transform.scale(
              scale: 0.85 + 0.15 * CurvedAnimation(
                parent: winAnim, curve: Curves.elasticOut).value,
              child: child,
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: _kHeaderBg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Colors.black38, blurRadius: 24, offset: Offset(0, 6)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events_rounded,
                      color: Color(0xFFFDD835), size: 56),
                  const SizedBox(height: 10),
                  const Text('Level Complete!',
                      style: TextStyle(
                        color: _kHeaderText,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      )),
                  const SizedBox(height: 14),
                  // Stars
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      final lit = i < stars;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          lit ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: lit
                              ? const Color(0xFFFDD835)
                              : _kHeaderLabel.withOpacity(0.4),
                          size: 36,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 14),
                  _ResultRow(label: 'Correct', value: '$correct of $total'),
                  const SizedBox(height: 22),
                  _GreenButton(
                    label: 'Level ${level + 1}',
                    onTap: onNext,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GameOverOverlay extends StatelessWidget {
  final int correct;
  final int total;
  final int level;
  final VoidCallback onRetry;

  const _GameOverOverlay({
    required this.correct,
    required this.total,
    required this.level,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: _kHeaderBg,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 24, offset: Offset(0, 6)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_off_rounded,
                    color: Color(0xFFE53935), size: 52),
                const SizedBox(height: 10),
                const Text('Time\'s Up!',
                    style: TextStyle(
                      color: _kHeaderText,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    )),
                const SizedBox(height: 14),
                _ResultRow(label: 'Correct', value: '$correct of $total'),
                const SizedBox(height: 8),
                _ResultRow(label: 'Level', value: '$level'),
                const SizedBox(height: 22),
                _GreenButton(label: 'Try Again', onTap: onRetry),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  const _ResultRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kHeaderDivider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: _kHeaderLabel, fontSize: 13)),
          Text(value,
              style: const TextStyle(
                color: _kHeaderText,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              )),
        ],
      ),
    );
  }
}

class _GreenButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GreenButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
        decoration: BoxDecoration(
          color: _kJunctionFill,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _kJunctionFill.withOpacity(0.50),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
