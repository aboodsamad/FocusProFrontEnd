import 'dart:math';

import 'package:capstone_front_end/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
 
import '../../../../core/providers/daily_score_provider.dart';
import '../../../../core/widgets/score_gain_toast.dart';
import '../../services/game_progress_service.dart';
import '../../services/game_service.dart';
import '../models/train_of_thought_model.dart';
 
// ─────────────────────────────────────────────────────────────────────────────
// Colour helpers
// ─────────────────────────────────────────────────────────────────────────────
 
Color _accent(TrainColor c) {
  switch (c) {
    case TrainColor.blue:   return const Color(0xFF2196F3);
    case TrainColor.pink:   return const Color(0xFFE91E8C);
    case TrainColor.red:    return const Color(0xFFE53935);
    case TrainColor.green:  return const Color(0xFF4CAF50);
    case TrainColor.yellow: return const Color(0xFFFDD835);
    case TrainColor.white:  return const Color(0xFFECEFF1);
  }
}
 
Color _dark(TrainColor c) {
  switch (c) {
    case TrainColor.blue:   return const Color(0xFF1565C0);
    case TrainColor.pink:   return const Color(0xFFC2185B);
    case TrainColor.red:    return const Color(0xFFB71C1C);
    case TrainColor.green:  return const Color(0xFF2E7D32);
    case TrainColor.yellow: return const Color(0xFFF57F17);
    case TrainColor.white:  return const Color(0xFF78909C);
  }
}
 
// ─────────────────────────────────────────────────────────────────────────────
// Game phase
// ─────────────────────────────────────────────────────────────────────────────
 
enum _Phase { idle, playing, complete, gameOver }
 
// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────
 
class TrainOfThoughtPage extends StatefulWidget {
  final int startLevel;

  const TrainOfThoughtPage({super.key, this.startLevel = 1});

  @override
  State<TrainOfThoughtPage> createState() => _TOTState();
}
 
class _TOTState extends State<TrainOfThoughtPage>
    with TickerProviderStateMixin {
 
  // ── game data ──────────────────────────────────────────────────────────────
  int _level = 1;
  late LevelConfig _cfg;                   // immutable template
  late Map<String, NetworkNode> _nodes;    // mutable per-play copy
 
  final List<TrainState> _trains = [];
  int _uidCounter = 0;
 
  int _correct  = 0;
  int _wrong    = 0;
  int _spawned  = 0;
  List<TrainColor> _activeSequence = [];   // shuffled each play
  double _spawnTimer = 0.0; // seconds until next spawn
 
  _Phase _phase = _Phase.idle;
 
  // ── animation ──────────────────────────────────────────────────────────────
  late Ticker _ticker;
  DateTime?   _prevTime;
 
  // per-station flash (green on correct, red on wrong)
  final Map<String, double> _stationFlash = {}; // nodeId → 0..1 fade
 
  // fork tap scale flash
  final Map<String, double> _forkFlash = {};
 
  // win/intro animation controllers
  late AnimationController _winAnim;
  late AnimationController _idleAnim;
 
  int _startEpoch = 0;
 
  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _winAnim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));
    _idleAnim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
 
    _ticker = createTicker(_onTick);
    _loadLevel(widget.startLevel);
  }
 
  @override
  void dispose() {
    _ticker.dispose();
    _winAnim.dispose();
    _idleAnim.dispose();
    super.dispose();
  }
 
  // ─────────────────────────────────────────────────────────────────────────
  // Level management
  // ─────────────────────────────────────────────────────────────────────────
 
  void _loadLevel(int lvl) {
    if (_ticker.isActive) _ticker.stop();
 
    _level   = lvl;
    _cfg     = LevelFactory.build(lvl).copyForPlay();
    _nodes   = _cfg.nodes;
 
    _trains.clear();
    _correct     = 0;
    _wrong       = 0;
    _spawned     = 0;
    _activeSequence = List<TrainColor>.from(_cfg.spawnPool)..shuffle(Random());
    _spawnTimer  = 1.0; // first train arrives after 1 second
    _phase       = _Phase.idle;
    _stationFlash.clear();
    _forkFlash.clear();
    _prevTime    = null;
 
    setState(() {});
  }
 
  void _startGame() {
    _startEpoch = DateTime.now().millisecondsSinceEpoch;
    _phase = _Phase.playing;
    _ticker.start();
    setState(() {});
  }
 
  // ─────────────────────────────────────────────────────────────────────────
  // Ticker callback – runs every frame (~60 fps)
  // ─────────────────────────────────────────────────────────────────────────
 
  void _onTick(Duration _) {
    if (!mounted) return;
    final now = DateTime.now();
    final dt  = _prevTime == null
        ? 0.016
        : now.difference(_prevTime!).inMicroseconds / 1e6;
    _prevTime = now;
 
    if (_phase != _Phase.playing) {
      // Still update flash decays even when not playing
      _decayFlashes(dt);
      setState(() {});
      return;
    }
 
    // ── move trains ──────────────────────────────────────────────────────────
    for (final train in _trains) {
      if (train.done) continue;
      _advanceTrain(train, dt);
    }
 
    // ── spawn next train ─────────────────────────────────────────────────────
    _spawnTimer -= dt;
    if (_spawnTimer <= 0 && _spawned < _activeSequence.length) {
      _spawnTrain();
      _spawnTimer = _cfg.spawnInterval;
    }
 
    // ── decay visual flashes ──────────────────────────────────────────────────
    _decayFlashes(dt);
 
    // ── check game over (too many wrong deliveries) ────────────────────────────
    if (_wrong >= _cfg.allowedMistakes) {
      _ticker.stop();
      _phase = _Phase.gameOver;
      _winAnim.forward(from: 0);
      _submitResult(completed: false);
      setState(() {});
      return;
    }

    // ── check completion ──────────────────────────────────────────────────────
    final allSpawned = _spawned >= _activeSequence.length;
    final allDone    = _trains.every((t) => t.done);
    if (allSpawned && allDone) {
      _ticker.stop();
      _phase = _Phase.complete;
      _winAnim.forward(from: 0);
      _submitResult(completed: true);
    }
 
    setState(() {});
  }
 
  void _decayFlashes(double dt) {
    for (final k in _stationFlash.keys.toList()) {
      _stationFlash[k] = ((_stationFlash[k]! - dt * 1.8)).clamp(0, 1);
      if (_stationFlash[k]! <= 0) _stationFlash.remove(k);
    }
    for (final k in _forkFlash.keys.toList()) {
      _forkFlash[k] = ((_forkFlash[k]! - dt * 3.0)).clamp(0, 1);
      if (_forkFlash[k]! <= 0) _forkFlash.remove(k);
    }
  }
 
  // ─────────────────────────────────────────────────────────────────────────
  // Train movement
  // ─────────────────────────────────────────────────────────────────────────
 
  void _advanceTrain(TrainState train, double dt) {
    final from = _nodes[train.fromId]!;
    final to   = _nodes[train.toId]!;
 
    // Euclidean length of this segment (in rel-units)
    final dx  = to.relX - from.relX;
    final dy  = to.relY - from.relY;
    final len = sqrt(dx * dx + dy * dy).clamp(0.01, 2.0);
 
    train.t += (_cfg.trainSpeed * dt) / len;
 
    if (train.t >= 1.0) {
      train.t = 1.0;
      _onReached(train, to);
    }
  }
 
  void _onReached(TrainState train, NetworkNode node) {
    if (node.isStation) {
      train.done    = true;
      train.correct = node.stationColor == train.color;
      if (train.correct) {
        _correct++;
        HapticFeedback.selectionClick();
      } else {
        _wrong++;
        HapticFeedback.heavyImpact();
      }
      _stationFlash[node.id] = 1.0;
      return;
    }
 
    // Move to next segment
    if (node.exitIds.isNotEmpty) {
      final nextId = node.isFork
          ? node.exitIds[node.activeExit]
          : node.exitIds[0];
      train.fromId = node.id;
      train.toId   = nextId;
      train.t      = 0.0;
    }
  }
 
  void _spawnTrain() {
    final color      = _activeSequence[_spawned];
    final tunnelNode = _nodes[_cfg.tunnelId]!;
    final firstExit  = tunnelNode.exitIds[0];
    _trains.add(TrainState(
      uid:    _uidCounter++,
      color:  color,
      fromId: _cfg.tunnelId,
      toId:   firstExit,
    ));
    _spawned++;
  }
 
  // ─────────────────────────────────────────────────────────────────────────
  // Fork interaction
  // ─────────────────────────────────────────────────────────────────────────
 
  void _tapFork(String id) {
    if (_phase != _Phase.playing) return;
    final node = _nodes[id];
    if (node == null || !node.isFork) return;
 
    node.activeExit = 1 - node.activeExit;
    _forkFlash[id] = 1.0;
    HapticFeedback.selectionClick();
    setState(() {});
  }
 
  // ─────────────────────────────────────────────────────────────────────────
  // Backend
  // ─────────────────────────────────────────────────────────────────────────
 
  Future<void> _submitResult({required bool completed}) async {
    final elapsed =
        (DateTime.now().millisecondsSinceEpoch - _startEpoch) ~/ 1000;
    // Completing a level unlocks the next one; failing keeps the current level unlocked.
    final unlockLevel = completed ? _level + 1 : _level;
    await GameProgressService.unlockUpToLevel('train_of_thought', unlockLevel);
    // Normalized score 0-1000: level + accuracy + completion bonus
    final int total = _correct + _wrong;
    final double accuracyRate = total > 0 ? _correct / total : 0.5;
    final int completionBonus = completed ? 100 : 0;
    final int normalizedScore = (_level * 150 + accuracyRate * 250 + completionBonus).round().clamp(0, 1000);
    final result = await GameService.submitResult(
      gameType: 'train_of_thought',
      score: normalizedScore,
      timePlayedSeconds: elapsed,
      completed: completed,
      levelReached: _level,
      mistakes: _wrong,
    );
    if (result != null && mounted) {
      context.read<DailyScoreProvider>().addPoints(result.focusScoreGained);
      ScoreGainToast.show(context, result.focusScoreGained, source: 'Train of Thought');
    }
  }
 
  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
 
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_phase == _Phase.playing) {
          _ticker.stop();
          _phase = _Phase.idle; // prevent further tick processing
          await _submitResult(completed: false);
        }
        if (mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              level:   _level,
              correct: _correct,
              total:   _activeSequence.length,
              onBack:  () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Stack(
                children: [
                  _buildBoard(),
                  if (_phase == _Phase.idle)
                    _IdleOverlay(
                      level: _level,
                      anim:  _idleAnim,
                      onStart: _startGame,
                    ),
                  if (_phase == _Phase.complete)
                    _CompleteOverlay(
                      level:   _level,
                      correct: _correct,
                      total:   _activeSequence.length,
                      wrong:   _wrong,
                      anim:    _winAnim,
                      onNext:  () {
                        _winAnim.reset();
                        _loadLevel(_level + 1);
                        Future.delayed(
                            const Duration(milliseconds: 200), _startGame);
                      },
                    ),
                  if (_phase == _Phase.gameOver)
                    _GameOverOverlay(
                      level:   _level,
                      correct: _correct,
                      wrong:   _wrong,
                      anim:    _winAnim,
                      onRetry: () {
                        _winAnim.reset();
                        _loadLevel(_level);
                        Future.delayed(
                            const Duration(milliseconds: 200), _startGame);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    )); // PopScope
  }

  Widget _buildBoard() {
    return LayoutBuilder(builder: (ctx, box) {
      final w = box.maxWidth;
      final h = box.maxHeight;
      return GestureDetector(
        onTapUp: (d) => _handleTap(d.localPosition, w, h),
        child: CustomPaint(
          size: Size(w, h),
          painter: _BoardPainter(
            nodes:        _nodes,
            trains:       _trains,
            stationFlash: _stationFlash,
            forkFlash:    _forkFlash,
          ),
        ),
      );
    });
  }
 
  void _handleTap(Offset pos, double w, double h) {
    // Find closest fork within tap radius
    const tapRadius = 38.0;
    String? best;
    double bestDist = tapRadius;
    for (final node in _nodes.values) {
      if (!node.isFork) continue;
      final nx = node.relX * w;
      final ny = node.relY * h;
      final d  = (pos - Offset(nx, ny)).distance;
      if (d < bestDist) {
        bestDist = d;
        best     = node.id;
      }
    }
    if (best != null) _tapFork(best);
  }
}
 
// ─────────────────────────────────────────────────────────────────────────────
// Board CustomPainter
// ─────────────────────────────────────────────────────────────────────────────
 
class _BoardPainter extends CustomPainter {
  final Map<String, NetworkNode> nodes;
  final List<TrainState>         trains;
  final Map<String, double>      stationFlash;
  final Map<String, double>      forkFlash;
 
  const _BoardPainter({
    required this.nodes,
    required this.trains,
    required this.stationFlash,
    required this.forkFlash,
  });
 
  // ── helpers ────────────────────────────────────────────────────────────────
 
  Offset _pt(NetworkNode n, Size sz) =>
      Offset(n.relX * sz.width, n.relY * sz.height);
 
  // ── main ───────────────────────────────────────────────────────────────────
 
  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawAllTracks(canvas, size);
    _drawTunnel(canvas, size);
    _drawForkNodes(canvas, size);
    _drawStations(canvas, size);
    _drawTrains(canvas, size);
  }
 
  // ── background ─────────────────────────────────────────────────────────────
 
  void _drawBackground(Canvas canvas, Size sz) {
    // base green field
    canvas.drawRect(
      Rect.fromLTWH(0, 0, sz.width, sz.height),
      Paint()..color = const Color(0xFF2E7D32),
    );
    // subtle lighter patches (grass texture)
    final p = Paint()..color = const Color(0xFF388E3C).withOpacity(0.25);
    final rng = Random(42);
    for (int i = 0; i < 18; i++) {
      final x = rng.nextDouble() * sz.width;
      final y = rng.nextDouble() * sz.height;
      final r = 18 + rng.nextDouble() * 28;
      canvas.drawCircle(Offset(x, y), r, p);
    }
    // corner trees
    _tree(canvas, sz.width * 0.04, sz.height * 0.06, sz);
    _tree(canvas, sz.width * 0.96, sz.height * 0.06, sz);
    _tree(canvas, sz.width * 0.04, sz.height * 0.94, sz);
    _tree(canvas, sz.width * 0.96, sz.height * 0.94, sz);
  }
 
  void _tree(Canvas canvas, double x, double y, Size sz) {
    final r = sz.width * 0.040;
    canvas.drawRect(
      Rect.fromLTWH(x - r * 0.18, y + r * 0.4, r * 0.36, r * 0.65),
      Paint()..color = const Color(0xFF4E342E).withOpacity(0.55),
    );
    // two canopy layers
    for (final (scale, opacity) in [(1.0, 0.65), (0.7, 0.80)]) {
      final path = Path()
        ..moveTo(x, y - r * scale)
        ..lineTo(x + r * scale * 1.0, y + r * scale * 0.55)
        ..lineTo(x - r * scale * 1.0, y + r * scale * 0.55)
        ..close();
      canvas.drawPath(
          path, Paint()..color = const Color(0xFF1B5E20).withOpacity(opacity));
    }
  }
 
  // ── tracks ─────────────────────────────────────────────────────────────────
 
  void _drawAllTracks(Canvas canvas, Size sz) {
    // collect all directed edges (parent → child) from the node graph
    for (final node in nodes.values) {
      if (node.isStation) continue;
      for (int i = 0; i < node.exitIds.length; i++) {
        final toNode = nodes[node.exitIds[i]];
        if (toNode == null) continue;
        final active = !node.isFork || i == node.activeExit;
        _drawSegment(canvas, sz, node, toNode, active: active);
      }
    }
  }
 
  void _drawSegment(Canvas canvas, Size sz,
      NetworkNode a, NetworkNode b, {required bool active}) {
    final pa = _pt(a, sz);
    final pb = _pt(b, sz);
 
    final bedW  = sz.width * 0.030;
    final railW = sz.width * 0.008;
 
    // track bed
    canvas.drawLine(
      pa, pb,
      Paint()
        ..color       = active
            ? const Color(0xFF795548)
            : const Color(0xFF4E342E).withOpacity(0.45)
        ..strokeWidth = bedW
        ..strokeCap   = StrokeCap.round
        ..style       = PaintingStyle.stroke,
    );
 
    if (active) {
      // parallel rails
      final dx  = pb.dx - pa.dx;
      final dy  = pb.dy - pa.dy;
      final len = sqrt(dx * dx + dy * dy);
      if (len > 0) {
        final nx  = -dy / len;
        final ny  =  dx / len;
        final off = bedW * 0.28;
        final railPaint = Paint()
          ..color       = const Color(0xFFBCAAA4).withOpacity(0.75)
          ..strokeWidth = railW
          ..strokeCap   = StrokeCap.butt
          ..style       = PaintingStyle.stroke;
        canvas.drawLine(
            pa + Offset(nx * off, ny * off),
            pb + Offset(nx * off, ny * off), railPaint);
        canvas.drawLine(
            pa - Offset(nx * off, ny * off),
            pb - Offset(nx * off, ny * off), railPaint);
 
        // crossties
        final count = max(3, (len / (sz.width * 0.07)).round());
        final tiePaint = Paint()
          ..color       = const Color(0xFF6D4C41).withOpacity(0.65)
          ..strokeWidth = bedW * 0.55
          ..strokeCap   = StrokeCap.square;
        for (int k = 1; k < count; k++) {
          final t   = k / count;
          final mid = Offset.lerp(pa, pb, t)!;
          canvas.drawLine(
            mid + Offset(nx * off * 1.5, ny * off * 1.5),
            mid - Offset(nx * off * 1.5, ny * off * 1.5),
            tiePaint,
          );
        }
      }
    }
  }
 
  // ── tunnel ─────────────────────────────────────────────────────────────────
 
  void _drawTunnel(Canvas canvas, Size sz) {
    final tunnel = nodes.values.firstWhere((n) => n.isTunnel,
        orElse: () => nodes.values.first);
    final p = _pt(tunnel, sz);
    final r = sz.width * 0.055;
 
    // mountain silhouette
    final mPath = Path()
      ..moveTo(p.dx - r * 1.6, p.dy + r * 0.6)
      ..lineTo(p.dx - r * 0.1, p.dy - r * 1.2)
      ..lineTo(p.dx + r * 1.4, p.dy + r * 0.6)
      ..close();
    canvas.drawPath(mPath, Paint()..color = const Color(0xFF546E7A));
    canvas.drawPath(
      mPath,
      Paint()
        ..color = const Color(0xFF78909C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
 
    // tunnel mouth (arch)
    final archRect = Rect.fromCenter(
        center: Offset(p.dx, p.dy + r * 0.15), width: r * 1.0, height: r * 1.4);
    final archPath = Path()
      ..addArc(
          Rect.fromLTWH(archRect.left, archRect.top,
              archRect.width, archRect.width),
          pi, pi)
      ..lineTo(archRect.right, archRect.bottom)
      ..lineTo(archRect.left,  archRect.bottom)
      ..close();
    canvas.drawPath(archPath, Paint()..color = const Color(0xFF1A237E));
    canvas.drawPath(
      archPath,
      Paint()
        ..color = const Color(0xFF3949AB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
 
  // ── fork nodes (circles) ───────────────────────────────────────────────────
 
  void _drawForkNodes(Canvas canvas, Size sz) {
    for (final node in nodes.values) {
      if (!node.isFork) continue;
      final p     = _pt(node, sz);
      final r     = sz.width * 0.048;
      final flash = forkFlash[node.id] ?? 0.0;
 
      // glow
      if (flash > 0) {
        canvas.drawCircle(
          p, r * (1.0 + 0.4 * flash),
          Paint()
            ..color = Colors.white.withOpacity(0.45 * flash)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        );
      }
 
      // shadow
      canvas.drawCircle(p + const Offset(2, 3), r,
          Paint()..color = Colors.black.withOpacity(0.30));
 
      // body
      final bodyColor = Color.lerp(
          const Color(0xFF66BB6A), Colors.white, flash * 0.5)!;
      canvas.drawCircle(p, r, Paint()..color = bodyColor);
 
      // border
      canvas.drawCircle(
        p, r,
        Paint()
          ..color       = const Color(0xFFA5D6A7)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = sz.width * 0.010,
      );
 
      // inner ring
      canvas.drawCircle(
        p, r * 0.6,
        Paint()
          ..color       = const Color(0xFF388E3C).withOpacity(0.4)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = sz.width * 0.006,
      );
 
      // direction arrow (points toward active exit)
      _drawForkArrow(canvas, sz, p, r, node);
    }
  }
 
  void _drawForkArrow(Canvas canvas, Size sz,
      Offset center, double r, NetworkNode node) {
    if (node.exitIds.isEmpty) return;
    final activeId  = node.exitIds[node.activeExit];
    final targetNode = nodes[activeId];
    if (targetNode == null) return;
 
    final tx = targetNode.relX * sz.width  - center.dx;
    final ty = targetNode.relY * sz.height - center.dy;
    final len = sqrt(tx * tx + ty * ty);
    if (len == 0) return;
    final ux = tx / len;
    final uy = ty / len;
 
    // arrow shaft
    final arrowPaint = Paint()
      ..color       = Colors.white.withOpacity(0.92)
      ..strokeWidth = sz.width * 0.009
      ..strokeCap   = StrokeCap.round;
    canvas.drawLine(
      center - Offset(ux * r * 0.38, uy * r * 0.38),
      center + Offset(ux * r * 0.52, uy * r * 0.52),
      arrowPaint,
    );
    // arrowhead
    final tip  = center + Offset(ux * r * 0.52, uy * r * 0.52);
    final perp = Offset(-uy, ux);
    final ah   = r * 0.18;
    final aw   = r * 0.10;
    final aPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo((tip - Offset(ux * ah, uy * ah) + perp * aw).dx,
               (tip - Offset(ux * ah, uy * ah) + perp * aw).dy)
      ..lineTo((tip - Offset(ux * ah, uy * ah) - perp * aw).dx,
               (tip - Offset(ux * ah, uy * ah) - perp * aw).dy)
      ..close();
    canvas.drawPath(aPath, Paint()..color = Colors.white.withOpacity(0.92));
  }
 
  // ── station buildings ───────────────────────────────────────────────────────
 
  void _drawStations(Canvas canvas, Size sz) {
    for (final node in nodes.values) {
      if (!node.isStation || node.stationColor == null) continue;
      final p     = _pt(node, sz);
      final flash = stationFlash[node.id] ?? 0.0;
      _drawBuilding(canvas, sz, p, node.stationColor!, flash);
    }
  }
 
  void _drawBuilding(Canvas canvas, Size sz, Offset center,
      TrainColor color, double flash) {
    final ac  = _accent(color);
    final dk  = _dark(color);
    final bw  = sz.width * 0.090;
    final bh  = sz.height * 0.072;
    final rh  = sz.height * 0.050;
 
    final left    = center.dx - bw / 2;
    final right   = center.dx + bw / 2;
    final bottom  = center.dy + bh * 0.55;
    final bodyTop = bottom - bh;
    final roofTop = bodyTop - rh;
 
    // flash glow (correct = green, wrong = red, default = station color)
    if (flash > 0) {
      canvas.drawCircle(
        center,
        bw * 0.9 * (1 + flash * 0.3),
        Paint()
          ..color = ac.withOpacity(0.5 * flash)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }
 
    // shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(left + 2, bodyTop + 3, right + 2, bottom + 3),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.black.withOpacity(0.28),
    );
 
    // body
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(left, bodyTop, right, bottom), const Radius.circular(3));
    canvas.drawRRect(bodyRect, Paint()..color = ac);
 
    // body highlight
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(left, bodyTop, left + bw * 0.22, bottom),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.white.withOpacity(0.22),
    );
    canvas.drawRRect(bodyRect,
      Paint()
        ..color = dk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
 
    // roof
    final roof = Path()
      ..moveTo(left  - bw * 0.07, bodyTop)
      ..lineTo(right + bw * 0.07, bodyTop)
      ..lineTo(right + bw * 0.07, roofTop + rh * 0.42)
      ..lineTo(center.dx, roofTop)
      ..lineTo(left  - bw * 0.07, roofTop + rh * 0.42)
      ..close();
    canvas.drawPath(roof, Paint()..color = dk);
    canvas.drawPath(
      roof,
      Paint()
        ..color = Colors.white.withOpacity(0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
 
    // door
    final doorW = bw * 0.26;
    final doorH = bh * 0.40;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          center.dx - doorW / 2, bottom - doorH,
          center.dx + doorW / 2, bottom,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = dk.withOpacity(0.70),
    );
 
    // windows
    final winW = bw * 0.22;
    final winH = bh * 0.26;
    final winY = bodyTop + bh * 0.14;
    for (final xo in [-bw * 0.26, bw * 0.26]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(center.dx + xo - winW / 2, winY,
              center.dx + xo + winW / 2, winY + winH),
          const Radius.circular(2),
        ),
        Paint()..color = Colors.white.withOpacity(0.82),
      );
    }
 
    // star on rooftop
    _drawStar(canvas, center.dx, roofTop - sz.height * 0.012,
        sz.width * 0.018, ac);
  }
 
  void _drawStar(
      Canvas canvas, double cx, double cy, double r, Color color) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final oa = -pi / 2 + 2 * pi * i / 5;
      final ia = oa + pi / 5;
      final op = Offset(cx + r * cos(oa), cy + r * sin(oa));
      final ip = Offset(cx + r * 0.45 * cos(ia), cy + r * 0.45 * sin(ia));
      if (i == 0) path.moveTo(op.dx, op.dy); else path.lineTo(op.dx, op.dy);
      path.lineTo(ip.dx, ip.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = Colors.white.withOpacity(0.90));
  }
 
  // ── trains ─────────────────────────────────────────────────────────────────
 
  void _drawTrains(Canvas canvas, Size sz) {
    for (final train in trains) {
      if (train.done) continue; // vanish immediately on arrival (correct or wrong)
      _drawOneTrain(canvas, sz, train);
    }
  }
 
  void _drawOneTrain(Canvas canvas, Size sz, TrainState train) {
    final from = nodes[train.fromId];
    final to   = nodes[train.toId];
    if (from == null || to == null) return;
 
    final fx = from.relX * sz.width;
    final fy = from.relY * sz.height;
    final tx = to.relX   * sz.width;
    final ty = to.relY   * sz.height;
 
    final cx = fx + (tx - fx) * train.t;
    final cy = fy + (ty - fy) * train.t;
 
    final angle = atan2(ty - fy, tx - fx);
    final r     = sz.width * 0.038;
 
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angle);
 
    final ac  = _accent(train.color);
    final dk  = _dark(train.color);
    final cw  = r * 2.0;
    final ch  = r * 1.3;
 
    // glow
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: cw * 1.1, height: ch * 1.1),
      Paint()
        ..color = ac.withOpacity(0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
 
    // body (elongated along travel direction = +x axis after rotation)
    final bodyRR = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(-r * 0.08, 0), width: cw, height: ch),
      Radius.circular(ch * 0.45),
    );
    canvas.drawRRect(bodyRR, Paint()..color = ac);
 
    // highlight
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(-cw * 0.42, -ch * 0.45, cw * 0.30, -ch * 0.05),
        Radius.circular(ch * 0.30),
      ),
      Paint()..color = Colors.white.withOpacity(0.30),
    );
 
    // nose (front, pointing +x)
    final nosePath = Path()
      ..moveTo(cw * 0.45,  ch * 0.48)
      ..lineTo(cw * 0.68,  0)
      ..lineTo(cw * 0.45, -ch * 0.48)
      ..close();
    canvas.drawPath(nosePath, Paint()..color = dk);
 
    // window
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(cw * 0.04, -ch * 0.37, cw * 0.38, ch * 0.30),
        Radius.circular(ch * 0.12),
      ),
      Paint()..color = Colors.white.withOpacity(0.88),
    );
 
    // outline
    canvas.drawRRect(
      bodyRR,
      Paint()
        ..color = dk
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.14,
    );
 
    // wheels
    final wheelPaint = Paint()..color = dk;
    final rimPaint   = Paint()
      ..color = Colors.white.withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.10;
    for (final wx in [-cw * 0.22, cw * 0.22]) {
      canvas.drawCircle(Offset(wx, ch * 0.52), r * 0.20, wheelPaint);
      canvas.drawCircle(Offset(wx, ch * 0.52), r * 0.10, rimPaint);
    }
 
    canvas.restore();
  }
 
  @override
  bool shouldRepaint(_BoardPainter old) => true;
}
 
// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────
 
class _Header extends StatelessWidget {
  final int level;
  final int correct;
  final int total;
  final VoidCallback onBack;
  const _Header({
    required this.level,
    required this.correct,
    required this.total,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final accuracy = total == 0 ? 0 : ((correct / total) * 100).round();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.primaryContainer,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Back + badges row
        Row(children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.onPrimary, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('LOGIC FLOW',
                style: TextStyle(color: AppColors.secondaryContainer, fontSize: 10,
                    fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('LEVEL $level',
                style: const TextStyle(color: AppColors.secondaryContainer, fontSize: 10,
                    fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          ),
          const Spacer(),
          // Score + accuracy pills
          _StatPill(label: 'CORRECT', value: '$correct/$total',
              color: AppColors.secondaryContainer),
          const SizedBox(width: 8),
          _StatPill(label: 'ACCURACY', value: '$accuracy%',
              color: AppColors.primaryFixed),
        ]),
      ]),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(children: [
        Text(label, style: TextStyle(color: color.withOpacity(0.7),
            fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1)),
        Text(value, style: TextStyle(color: color,
            fontSize: 13, fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

class _Cell extends StatelessWidget {
  final String label;
  final String value;
  const _Cell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(color: Colors.grey[500],
            fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
        const SizedBox(height: 1),
        Text(value, style: const TextStyle(color: Colors.white,
            fontSize: 15, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}
 
// ─────────────────────────────────────────────────────────────────────────────
// Idle overlay
// ─────────────────────────────────────────────────────────────────────────────
 
class _IdleOverlay extends StatelessWidget {
  final int level;
  final AnimationController anim;
  final VoidCallback onStart;
  const _IdleOverlay({
    required this.level,
    required this.anim,
    required this.onStart,
  });
 
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.75),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1524),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF8B5CF6).withOpacity(0.2),
                    blurRadius: 40, spreadRadius: 4),
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedBuilder(
                animation: anim,
                builder: (_, child) => Transform.translate(
                  offset: Offset(0, -6 * anim.value), child: child),
                child: Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFF8B5CF6).withOpacity(0.5),
                          blurRadius: 24, spreadRadius: 4),
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
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text('Route trains to matching color stations',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              const _Hint(
                  icon: Icons.touch_app_rounded,
                  text: 'Tap the circles to switch tracks'),
              const SizedBox(height: 6),
              const _Hint(
                  icon: Icons.compare_arrows_rounded,
                  text: 'Route each train to its matching station'),
              const SizedBox(height: 6),
              const _Hint(
                  icon: Icons.directions_railway_rounded,
                  text: 'Trains leave one by one'),
              const SizedBox(height: 24),
              _GreenBtn(
                label: level == 1 ? 'Start Game' : 'Level $level',
                onTap: onStart,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
 
class _Hint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Hint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: const Color(0xFFA78BFA), size: 16),
      const SizedBox(width: 8),
      Flexible(
        child: Text(text,
            style: TextStyle(color: Colors.grey[400], fontSize: 12.5)),
      ),
    ]);
  }
}
 
// ─────────────────────────────────────────────────────────────────────────────
// Level complete overlay
// ─────────────────────────────────────────────────────────────────────────────
 
class _CompleteOverlay extends StatelessWidget {
  final int level;
  final int correct;
  final int total;
  final int wrong;
  final AnimationController anim;
  final VoidCallback onNext;
 
  const _CompleteOverlay({
    required this.level,
    required this.correct,
    required this.total,
    required this.wrong,
    required this.anim,
    required this.onNext,
  });
 
  int get _stars => wrong == 0 ? 3 : wrong == 1 ? 2 : 1;
 
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.55),
        child: Center(
          child: AnimatedBuilder(
            animation: anim,
            builder: (_, child) => Transform.scale(
              scale: 0.85 +
                  0.15 *
                      CurvedAnimation(
                              parent: anim, curve: Curves.elasticOut)
                          .value,
              child: child,
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1524),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF34D399).withOpacity(0.2),
                      blurRadius: 40, spreadRadius: 4),
                ],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 70, height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                        colors: [Color(0xFF34D399), Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    boxShadow: [BoxShadow(
                        color: const Color(0xFF34D399).withOpacity(0.45),
                        blurRadius: 24, spreadRadius: 4)],
                  ),
                  child: const Icon(Icons.emoji_events_rounded,
                      color: Colors.white, size: 36),
                ),
                const SizedBox(height: 14),
                const Text('Level Complete!',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    final lit = i < _stars;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        lit ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: lit
                            ? const Color(0xFFFBBF24)
                            : Colors.grey[700],
                        size: 36,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                _Row(label: 'Correct', value: '$correct / $total'),
                if (wrong > 0) ...[
                  const SizedBox(height: 6),
                  _Row(label: 'Wrong station', value: '$wrong'),
                ],
                const SizedBox(height: 24),
                _GreenBtn(label: 'Level ${level + 1}', onTap: onNext),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
 
// ─────────────────────────────────────────────────────────────────────────────
// _GameOverOverlay — shown when wrong deliveries reach allowedMistakes
// ─────────────────────────────────────────────────────────────────────────────

class _GameOverOverlay extends StatelessWidget {
  final int level;
  final int correct;
  final int wrong;
  final AnimationController anim;
  final VoidCallback onRetry;

  const _GameOverOverlay({
    required this.level,
    required this.correct,
    required this.wrong,
    required this.anim,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.60),
        child: Center(
          child: AnimatedBuilder(
            animation: anim,
            builder: (_, child) => Transform.scale(
              scale: 0.85 +
                  0.15 *
                      CurvedAnimation(parent: anim, curve: Curves.elasticOut)
                          .value,
              child: child,
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1524),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFFEF4444).withOpacity(0.2),
                      blurRadius: 40, spreadRadius: 4),
                ],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 70, height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                        colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    boxShadow: [BoxShadow(
                        color: const Color(0xFFEF4444).withOpacity(0.45),
                        blurRadius: 24, spreadRadius: 4)],
                  ),
                  child: const Icon(Icons.train_rounded,
                      color: Colors.white, size: 36),
                ),
                const SizedBox(height: 14),
                const Text('Too Many Crashes!',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text('Level $level',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                const SizedBox(height: 16),
                _Row(label: 'Correct',  value: '$correct'),
                const SizedBox(height: 6),
                _Row(label: 'Crashes',  value: '$wrong'),
                const SizedBox(height: 24),
                _GreenBtn(label: 'Try Again', onTap: onRetry),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          Text(value, style: const TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
 
class _GreenBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GreenBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withOpacity(0.45),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3)),
      ),
    );
  }
}