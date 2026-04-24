import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:capstone_front_end/core/constants/app_colors.dart';
import '../models/number_stream_model.dart';
import '../../services/game_progress_service.dart';
import '../../services/game_service.dart';
import '../../../../core/providers/daily_score_provider.dart';
import '../../../../core/widgets/score_gain_toast.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design constants  — Deep Focus dark-canvas palette
// ─────────────────────────────────────────────────────────────────────────────

const _kBg        = AppColors.primary;               // #012D1D deep forest
const _kSurface   = AppColors.primaryContainer;      // #1B4332
const _kCard      = AppColors.primaryContainer;      // #1B4332
const _kBorder    = AppColors.onPrimaryFixedVariant; // #274E3D subtle border
const _kAccent    = AppColors.secondaryContainer;    // #A0F4C8 mint
const _kAccentDim = Color(0x28A0F4C8);               // mint @16 %
const _kCorrect   = AppColors.secondaryContainer;    // mint for correct
const _kWrong     = AppColors.error;                 // #BA1A1A
const _kGold      = AppColors.primaryFixed;          // #C1ECD4 pale mint
const _kText      = AppColors.onPrimary;             // white
const _kMuted     = AppColors.onPrimaryContainer;    // #86AF99

// ─────────────────────────────────────────────────────────────────────────────
// Particle
// ─────────────────────────────────────────────────────────────────────────────

class _Particle {
  final double ox, oy, vx, vy, size;
  final Color color;
  _Particle({
    required this.ox, required this.oy,
    required this.vx, required this.vy,
    required this.size, required this.color,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class NumberStreamPage extends StatefulWidget {
  final int startLevel;

  const NumberStreamPage({super.key, this.startLevel = 1});

  @override
  State<NumberStreamPage> createState() => _NumberStreamPageState();
}

class _NumberStreamPageState extends State<NumberStreamPage>
    with TickerProviderStateMixin {

  // ── Game state ──────────────────────────────────────────────────────────────
  NumberStreamState _game    = NumberStreamState.initial();
  DateTime?         _startTime;
  int?              _tappedIdx;   // which button index was tapped
  bool              _correct = false;
  bool              _feedback = false; // true while showing tap result

  // ── 2-minute session timer (no-lives system) ─────────────────────────────
  Timer? _sessionTimer;
  int    _sessionSecondsLeft = 120;

  // ── Animation controllers ───────────────────────────────────────────────────
  late final AnimationController _fallCtrl;   // drives equation fall 0→1
  late final AnimationController _burstCtrl;  // particle explosion 0→1
  late final AnimationController _shakeCtrl;  // horizontal shake
  late final AnimationController _cdCtrl;     // countdown digit pulse
  late final AnimationController _pulseCtrl;  // background ambient pulse
  late final AnimationController _levelCtrl;  // level-up zoom

  // ── Particles ───────────────────────────────────────────────────────────────
  final List<_Particle> _particles = [];
  Offset _burstAt = Offset.zero;

  // ── Misc ────────────────────────────────────────────────────────────────────
  int    _cdValue      = 3;
  double _areaHeight   = 400;
  final  _rng          = Random();

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    _fallCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 5200),
    )..addStatusListener(_onFallStatus);

    _burstCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 650),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) setState(() => _particles.clear());
      });

    _shakeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 380),
    );

    _cdCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 750),
    );

    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _levelCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _fallCtrl.dispose();
    _burstCtrl.dispose();
    _shakeCtrl.dispose();
    _cdCtrl.dispose();
    _pulseCtrl.dispose();
    _levelCtrl.dispose();
    _sessionTimer?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Game flow
  // ─────────────────────────────────────────────────────────────────────────

  void _startGame() {
    _startTime = DateTime.now();
    _sessionSecondsLeft = 120;
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      final remaining = _sessionSecondsLeft - 1;
      if (remaining <= 0) {
        t.cancel();
        setState(() => _sessionSecondsLeft = 0);
        _endGame();
      } else {
        setState(() => _sessionSecondsLeft = remaining);
      }
    });
    resetEqCounter(); // reset equation ID counter so IDs start from 1 each game
    setState(() {
      _game    = NumberStreamState.initial()
          .copyWith(level: widget.startLevel, phase: NumberStreamPhase.countdown);
      _cdValue = 3;
      _particles.clear();
    });
    _runCountdown();
  }

  Future<void> _runCountdown() async {
    for (int i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() => _cdValue = i);
      _cdCtrl.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 900));
    }
    if (!mounted) return;
    setState(() => _cdValue = 0); // shows "GO!"
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) _nextEquation();
  }

  void _nextEquation() {
    if (!mounted) return;
    final eq = generateEquation(_game.level);
    setState(() {
      _game    = _game.copyWith(equation: eq, phase: NumberStreamPhase.playing);
      _tappedIdx = null;
      _feedback  = false;
      _correct   = false;
    });
    _fallCtrl.duration = Duration(milliseconds: _game.fallDurationMs);
    _fallCtrl.forward(from: 0);
  }

  void _onFallStatus(AnimationStatus s) {
    if (s != AnimationStatus.completed) return;
    if (_game.phase != NumberStreamPhase.playing) return;
    if (_feedback) return;
    _handleMissed();
  }

  void _onAnswerTap(int choice, int idx) {
    if (_game.phase != NumberStreamPhase.playing || _feedback) return;
    _fallCtrl.stop();
    HapticFeedback.lightImpact();

    final isCorrect = choice == _game.equation!.answer;

    setState(() {
      _tappedIdx = idx;
      _correct   = isCorrect;
      _feedback  = true;
    });

    if (isCorrect) {
      _handleCorrect();
    } else {
      _handleWrong();
    }
  }

  void _handleCorrect() {
    // Spawn burst at equation's current Y
    final eqY = _fallCtrl.value * (_areaHeight - 100) + 44;
    _burstAt = Offset(MediaQuery.of(context).size.width / 2, eqY);
    _spawnParticles();
    _burstCtrl.forward(from: 0);

    final speedBonus  = ((1.0 - _fallCtrl.value) * 60).round();
    final points      = _game.answerPoints + speedBonus;
    final newStreak   = _game.streak + 1;
    final newSolved   = _game.solved + 1;
    final doLevelUp   = newSolved >= _game.perLevel;

    setState(() {
      _game = _game.copyWith(
        score:      _game.score + points,
        streak:     newStreak,
        bestStreak: newStreak > _game.bestStreak ? newStreak : _game.bestStreak,
        solved:     doLevelUp ? 0 : newSolved,
        level:      doLevelUp ? _game.level + 1 : _game.level,
      );
    });

    Future.delayed(const Duration(milliseconds: 550), () {
      if (!mounted) return;
      if (doLevelUp) {
        _levelCtrl.forward(from: 0);
        setState(() => _game = _game.copyWith(phase: NumberStreamPhase.levelUp));
        Future.delayed(const Duration(milliseconds: 1900), () {
          if (mounted) _nextEquation();
        });
      } else {
        _nextEquation();
      }
    });
  }

  void _handleWrong() {
    HapticFeedback.heavyImpact();
    _shakeCtrl.forward(from: 0);
    // No lives system — mistakes never end the game, session timer does.
    setState(() => _game = _game.copyWith(streak: 0, mistakes: _game.mistakes + 1));
    Future.delayed(const Duration(milliseconds: 750), () {
      if (mounted) _nextEquation();
    });
  }

  void _handleMissed() {
    HapticFeedback.heavyImpact();
    _shakeCtrl.forward(from: 0);
    // No lives system — mistakes never end the game, session timer does.
    setState(() => _game = _game.copyWith(streak: 0, mistakes: _game.mistakes + 1, clearEquation: true));
    Future.delayed(const Duration(milliseconds: 550), () {
      if (mounted) _nextEquation();
    });
  }

  void _endGame() {
    _sessionTimer?.cancel();
    setState(() => _game = _game.copyWith(phase: NumberStreamPhase.gameOver));
    _submitResult();
  }

  Future<void> _submitResult() async {
    final secs = _startTime != null
        ? DateTime.now().difference(_startTime!).inSeconds
        : 0;
    await GameProgressService.unlockUpToLevel('number_stream', _game.level);
    // Normalized score 0-1000: level contribution + accuracy
    final double accuracyFactor = (1.0 - (_game.mistakes * 0.05).clamp(0.0, 1.0));
    final int normalizedScore = (_game.level * 80 + accuracyFactor * 200).round().clamp(0, 1000);
    final result = await GameService.submitResult(
      gameType:          'number_stream',
      score:             normalizedScore,
      timePlayedSeconds: secs,
      completed:         true,
      levelReached:      _game.level,
      mistakes:          _game.mistakes,
    );
    if (result != null && mounted) {
      context.read<DailyScoreProvider>().addPoints(result.focusScoreGained);
      ScoreGainToast.show(context, result.focusScoreGained, source: 'Number Stream');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Particles
  // ─────────────────────────────────────────────────────────────────────────

  void _spawnParticles() {
    const colors = [_kAccent, _kCorrect, _kGold, AppColors.onPrimary, AppColors.primaryFixed];
    _particles.clear();
    for (int i = 0; i < 28; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = _rng.nextDouble() * 7 + 2;
      _particles.add(_Particle(
        ox: _burstAt.dx, oy: _burstAt.dy,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        size: _rng.nextDouble() * 7 + 3,
        color: colors[_rng.nextInt(colors.length)],
      ));
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
        final isPlaying = _game.phase == NumberStreamPhase.playing ||
            _game.phase == NumberStreamPhase.levelUp;
        if (isPlaying) {
          _fallCtrl.stop();
          await _submitResult();
        }
        if (mounted) Navigator.pop(context);
      },
      child: Scaffold(
      backgroundColor: _kBg,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _fallCtrl, _burstCtrl, _shakeCtrl, _pulseCtrl, _levelCtrl, _cdCtrl,
        ]),
        builder: (context, _) {
          final shakeX = sin(_shakeCtrl.value * pi * 9) * 14 * (1 - _shakeCtrl.value);
          return Transform.translate(
            offset: Offset(shakeX, 0),
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  _buildProgressBar(),
                  Expanded(
                    child: LayoutBuilder(builder: (ctx, box) {
                      _areaHeight = box.maxHeight;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Ambient background
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _BgPainter(_pulseCtrl.value),
                            ),
                          ),
                          // Falling equation
                          if (_game.equation != null &&
                              (_game.phase == NumberStreamPhase.playing ||
                               _game.phase == NumberStreamPhase.levelUp))
                            _buildFallingEquation(box),
                          // Streak badge
                          if (_game.streak >= 2 &&
                              _game.phase == NumberStreamPhase.playing)
                            _buildStreakBadge(),
                          // Overlays
                          if (_game.phase == NumberStreamPhase.idle)
                            _buildIdleOverlay(),
                          if (_game.phase == NumberStreamPhase.countdown)
                            _buildCountdownOverlay(),
                          if (_game.phase == NumberStreamPhase.levelUp)
                            _buildLevelUpOverlay(),
                          if (_game.phase == NumberStreamPhase.gameOver)
                            _buildGameOverOverlay(),
                          // Particles
                          if (_particles.isNotEmpty)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _ParticlePainter(
                                    _particles, _burstCtrl.value),
                              ),
                            ),
                        ],
                      );
                    }),
                  ),
                  // Answer grid — fixed height so it never causes overflow on rotation
                  _buildAnswerSection(context),
                ],
              ),
            ),
          );
        },
      ),
    )); // PopScope
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Header
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kBorder),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: _kText, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          // Lives
          Row(
            children: List.generate(3, (i) {
              final alive = i < _game.lives;
              return Padding(
                padding: const EdgeInsets.only(right: 5),
                child: AnimatedScale(
                  scale: alive ? 1.0 : 0.65,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.elasticOut,
                  child: Icon(
                    alive
                        ? Icons.favorite_rounded
                        : Icons.favorite_outline_rounded,
                    color: alive ? _kWrong : _kBorder,
                    size: 22,
                  ),
                ),
              );
            }),
          ),
          const Spacer(),
          // Level badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _kAccentDim,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kAccent.withOpacity(0.45)),
            ),
            child: Text(
              'LVL ${_game.level}',
              style: const TextStyle(
                  color: _kAccent, fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          // Score
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_game.score}',
                style: const TextStyle(
                    color: _kText, fontWeight: FontWeight.w900, fontSize: 22),
              ),
              Text(
                'SCORE',
                style: TextStyle(
                    color: _kMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Level progress bar
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildProgressBar() {
    final progress = _game.levelProgress;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Level progress',
                  style: TextStyle(color: _kMuted, fontSize: 11, fontWeight: FontWeight.w600)),
              Text('${_game.solved} / ${_game.perLevel}',
                  style: TextStyle(color: _kMuted, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 5,
              child: Stack(
                children: [
                  Container(color: _kBorder),
                  AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 300),
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _kAccent,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                              color: _kAccent.withOpacity(0.5), blurRadius: 6)
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Streak badge
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStreakBadge() {
    return Positioned(
      top: 10,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _kGold.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kGold.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_fire_department_rounded,
                  color: _kGold, size: 16),
              const SizedBox(width: 5),
              Text(
                '${_game.streak}× streak',
                style: const TextStyle(
                    color: _kGold, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Falling equation card
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildFallingEquation(BoxConstraints box) {
    final eq       = _game.equation!;
    final t        = _fallCtrl.value;
    final topY     = t * (box.maxHeight - 130);
    final danger   = (t * 1.6).clamp(0.0, 1.0);
    final glowCol  = Color.lerp(_kAccent, _kWrong, danger)!;
    final scale    = 1.0 + t * 0.08;

    Color borderCol = glowCol;
    if (_feedback) borderCol = _correct ? _kCorrect : _kWrong;

    // Responsive sizing relative to the available play-area width
    final areaW    = box.maxWidth;
    final eqFontSz = (areaW * 0.10).clamp(28.0, 46.0);
    final subFontSz = (areaW * 0.055).clamp(16.0, 24.0);
    final hPad     = (areaW * 0.08).clamp(20.0, 40.0);
    final vPad     = (box.maxHeight * 0.04).clamp(12.0, 24.0);
    final maxW     = (areaW * 0.75).clamp(200.0, 340.0);

    return Positioned(
      top: topY,
      left: 0,
      right: 0,
      child: Transform.scale(
        scale: scale,
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: maxW),
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderCol, width: 2.5),
              boxShadow: [
                BoxShadow(
                    color: borderCol.withOpacity(0.55),
                    blurRadius: 32,
                    spreadRadius: 3),
                BoxShadow(
                    color: borderCol.withOpacity(0.18), blurRadius: 80),
                BoxShadow(
                    color: AppColors.onPrimary.withOpacity(0.04),
                    blurRadius: 0,
                    spreadRadius: -1),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  eq.expression,
                  style: TextStyle(
                    color: AppColors.onPrimary,
                    fontSize: eqFontSz,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    shadows: [
                      Shadow(color: borderCol.withOpacity(0.8), blurRadius: 20)
                    ],
                  ),
                ),
                SizedBox(height: vPad * 0.4),
                Text(
                  '= ?',
                  style: TextStyle(
                    color: borderCol,
                    fontSize: subFontSz,
                    fontWeight: FontWeight.w800,
                    shadows: [
                      Shadow(color: borderCol.withOpacity(0.6), blurRadius: 10)
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Answer section — fixed height so landscape rotation never overflows
  // ─────────────────────────────────────────────────────────────────────────

  /// Wraps the answer grid in a fixed-height slot.
  /// The slot is always the same height whether the grid is shown or not,
  /// so the Expanded game-area above never jumps or shrinks.
  Widget _buildAnswerSection(BuildContext context) {
    final mq      = MediaQuery.of(context);
    final screenH = mq.size.height;
    final btnH    = (screenH * 0.075).clamp(44.0, 62.0);
    // total slot = 2 button rows + 1 gap + top padding + bottom padding
    final slotH   = btnH * 2 + 10 + 10 + 12;

    final show = _game.phase == NumberStreamPhase.playing ||
        (_game.phase == NumberStreamPhase.levelUp && _feedback);

    return SizedBox(
      height: slotH,
      child: AnimatedOpacity(
        opacity: show ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: show ? _buildAnswerGrid(context, btnH) : const SizedBox.shrink(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Answer grid (2 × 2)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildAnswerGrid(BuildContext context, double btnH) {
    if (_game.equation == null) return const SizedBox.shrink();
    final choices   = _game.equation!.choices;
    final correct   = _game.equation!.answer;
    final screenW   = MediaQuery.of(context).size.width;
    final fontSize  = (screenW * 0.055).clamp(18.0, 26.0);

    Widget btn(int i) {
      final choice    = choices[i];
      Color bg        = _kCard;
      Color border    = _kBorder;
      Color textColor = _kText;

      if (_feedback) {
        if (_tappedIdx == i) {
          bg        = (_correct ? _kCorrect : _kWrong).withOpacity(0.18);
          border    = _correct ? _kCorrect : _kWrong;
          textColor = _correct ? _kCorrect : _kWrong;
        } else if (choice == correct && !_correct) {
          bg        = _kCorrect.withOpacity(0.10);
          border    = _kCorrect.withOpacity(0.55);
          textColor = _kCorrect;
        }
      }

      return Expanded(
        child: GestureDetector(
          onTap: () => _onAnswerTap(choice, i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: btnH,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border, width: 1.5),
              boxShadow: border != _kBorder
                  ? [BoxShadow(color: border.withOpacity(0.35), blurRadius: 14)]
                  : [],
            ),
            child: Center(
              child: Text(
                '$choice',
                style: TextStyle(
                  color: textColor,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [btn(0), const SizedBox(width: 10), btn(1)]),
          const SizedBox(height: 10),
          Row(children: [btn(2), const SizedBox(width: 10), btn(3)]),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Idle overlay
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildIdleOverlay() {
    return Positioned.fill(
      child: Container(
        color: _kBg.withOpacity(0.93),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: 96, height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.secondaryContainer,
                    boxShadow: [
                      BoxShadow(
                          color: _kAccent.withOpacity(0.45), blurRadius: 36)
                    ],
                  ),
                  child: const Icon(Icons.functions_rounded,
                      color: AppColors.primary, size: 44),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Number Stream',
                  style: TextStyle(
                      color: _kText,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'Equations fall from above.\nSolve them before they hit the bottom!\nAnswer fast for speed bonuses.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: _kMuted, fontSize: 15, height: 1.6),
                ),
                const SizedBox(height: 28),
                // Operation chips
                Wrap(
                  spacing: 8, runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: const [
                    _OpChip(label: '+ Addition',       level: 'Lvl 1'),
                    _OpChip(label: '− Subtraction',    level: 'Lvl 2'),
                    _OpChip(label: '× Multiplication', level: 'Lvl 4'),
                    _OpChip(label: '⚡ Mixed',          level: 'Lvl 5+'),
                  ],
                ),
                const SizedBox(height: 36),
                GestureDetector(
                  onTap: _startGame,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 56, vertical: 18),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryContainer,
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                            color: _kAccent.withOpacity(0.45),
                            blurRadius: 28,
                            offset: const Offset(0, 10))
                      ],
                    ),
                    child: const Text(
                      'PLAY',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3),
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

  // ─────────────────────────────────────────────────────────────────────────
  // Countdown overlay
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildCountdownOverlay() {
    return Positioned.fill(
      child: Container(
        color: _kBg.withOpacity(0.88),
        child: Center(
          child: AnimatedBuilder(
            animation: _cdCtrl,
            builder: (_, __) {
              final v       = _cdCtrl.value;
              final scale   = 1.5 - v * 0.5;
              final opacity = v < 0.7 ? 1.0 : 1.0 - ((v - 0.7) / 0.3);
              return Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale,
                  child: Text(
                    _cdValue == 0 ? 'GO!' : '$_cdValue',
                    style: TextStyle(
                      color: _cdValue == 0 ? _kCorrect : _kText,
                      fontSize: 88,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                          color: (_cdValue == 0 ? _kCorrect : _kAccent)
                              .withOpacity(0.6),
                          blurRadius: 30,
                        )
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Level-up overlay
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildLevelUpOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: _kBg.withOpacity(0.82),
          child: Center(
            child: ScaleTransition(
              scale: CurvedAnimation(parent: _levelCtrl, curve: Curves.elasticOut),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_circle_up_rounded,
                      color: _kGold, size: 64),
                  const SizedBox(height: 14),
                  Text(
                    'LEVEL ${_game.level}',
                    style: const TextStyle(
                      color: _kGold,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      shadows: [Shadow(color: _kGold, blurRadius: 24)],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _levelFlavour(_game.level),
                    style: TextStyle(color: _kMuted, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _levelFlavour(int level) {
    switch (level) {
      case 2: return 'Subtraction unlocked!';
      case 3: return 'Numbers getting bigger…';
      case 4: return 'Multiplication unlocked!';
      case 5: return 'Mixed operations — stay sharp!';
      default: return 'Equations are falling faster!';
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Game-over overlay
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildGameOverOverlay() {
    return Positioned.fill(
      child: Container(
        color: _kBg.withOpacity(0.95),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kWrong.withOpacity(0.12),
                    border: Border.all(color: _kWrong.withOpacity(0.4)),
                  ),
                  child: const Icon(Icons.sentiment_dissatisfied_rounded,
                      color: _kWrong, size: 40),
                ),
                const SizedBox(height: 18),
                const Text('Game Over',
                    style: TextStyle(
                        color: _kText,
                        fontSize: 34,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 28),
                // Stats card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Column(
                    children: [
                      _StatRow('Final Score',   '${_game.score}',      _kAccent),
                      const SizedBox(height: 16),
                      _StatRow('Level Reached', '${_game.level}',      _kGold),
                      const SizedBox(height: 16),
                      _StatRow('Best Streak',   '${_game.bestStreak}×', _kCorrect),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: _kCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _kBorder),
                          ),
                          child: const Center(
                            child: Text('Exit',
                                style: TextStyle(
                                    color: _kMuted,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _startGame,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryContainer,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                  color: _kAccent.withOpacity(0.38),
                                  blurRadius: 18)
                            ],
                          ),
                          child: const Center(
                            child: Text('Play Again',
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _OpChip extends StatelessWidget {
  final String label;
  final String level;
  const _OpChip({required this.label, required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  color: _kText, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _kAccentDim,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(level,
                style: const TextStyle(
                    color: _kAccent, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: _kMuted, fontSize: 15, fontWeight: FontWeight.w500)),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                shadows: [Shadow(color: color.withOpacity(0.4), blurRadius: 8)])),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CustomPainters
// ─────────────────────────────────────────────────────────────────────────────

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double t; // 0 → 1

  const _ParticlePainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final x       = p.ox + p.vx * t * 48;
      final y       = p.oy + p.vy * t * 48 + 60 * t * t; // gravity
      final opacity = (1.0 - t * 1.3).clamp(0.0, 1.0);
      final radius  = p.size * (1 - t * 0.4);
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = p.color.withOpacity(opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.t != t;
}

class _BgPainter extends CustomPainter {
  final double pulse; // 0 → 1 looping

  const _BgPainter(this.pulse);

  @override
  void paint(Canvas canvas, Size size) {
    // Subtle grid
    final linePaint = Paint()
      ..color = AppColors.onPrimaryFixedVariant.withOpacity(0.4)
      ..strokeWidth = 0.6;

    const step = 44.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Ambient radial glow
    final cx     = size.width / 2;
    final cy     = size.height * 0.38;
    final radius = size.width * (0.55 + pulse * 0.06);
    canvas.drawCircle(
      Offset(cx, cy),
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.secondaryContainer.withOpacity(0.045 + pulse * 0.018),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.pulse != pulse;
}
