import 'dart:async';
import 'dart:math' as math;

import 'package:capstone_front_end/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/daily_score_provider.dart';
import '../../../../core/widgets/score_gain_toast.dart';
import '../../services/game_progress_service.dart';
import '../../services/game_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design constants — Deep Focus light theme
// ─────────────────────────────────────────────────────────────────────────────

const _kBg      = AppColors.surface;
const _kCard    = AppColors.primaryContainer;
const _kBorder  = AppColors.outlineVariant;
const _kAccent  = AppColors.secondaryContainer;
const _kGold    = AppColors.primaryFixed;
const _kWrong   = AppColors.error;
const _kCorrect = AppColors.secondaryContainer;
const _kMuted   = AppColors.onSurfaceVariant;

// ─────────────────────────────────────────────────────────────────────────────
// Level-based difficulty helpers
// ─────────────────────────────────────────────────────────────────────────────

/// 3×3 grid for levels 1–5, 4×4 for levels 6–10.
int _gridSizeForLevel(int level) => level <= 5 ? 3 : 4;

/// Sequence length: starts at 3 for level 1, +1 each level.
int _seqLenForLevel(int level) => level + 2;

/// Dot-on duration (ms): starts at 800 ms, decreases 40 ms per level, min 300 ms.
int _dotOnMsForLevel(int level) => (800 - (level - 1) * 40).clamp(300, 800);

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

enum _Phase { idle, countdown, showing, input, levelComplete, gameOver }

class _GameState {
  final _Phase phase;
  final int    level;
  final int    sequenceLength;
  final List<int> sequence;
  final int    playerProgress;
  final int    score;
  final int    lives;
  final int    mistakes;
  final int    countdown;

  const _GameState({
    required this.phase,
    required this.level,
    required this.sequenceLength,
    required this.sequence,
    required this.playerProgress,
    required this.score,
    required this.lives,
    required this.mistakes,
    required this.countdown,
  });

  factory _GameState.initial(int level) => _GameState(
        phase:          _Phase.idle,
        level:          level,
        sequenceLength: _seqLenForLevel(level),
        sequence:       const [],
        playerProgress: 0,
        score:          0,
        lives:          3,
        mistakes:       0,
        countdown:      3,
      );

  int get gridSize  => _gridSizeForLevel(level);
  int get dotCount  => gridSize * gridSize;
  int get roundPoints => level * sequenceLength * 10;

  _GameState copyWith({
    _Phase?   phase,
    int?      level,
    int?      sequenceLength,
    List<int>? sequence,
    int?      playerProgress,
    int?      score,
    int?      lives,
    int?      mistakes,
    int?      countdown,
  }) => _GameState(
        phase:          phase          ?? this.phase,
        level:          level          ?? this.level,
        sequenceLength: sequenceLength ?? this.sequenceLength,
        sequence:       sequence       ?? this.sequence,
        playerProgress: playerProgress ?? this.playerProgress,
        score:          score          ?? this.score,
        lives:          lives          ?? this.lives,
        mistakes:       mistakes       ?? this.mistakes,
        countdown:      countdown      ?? this.countdown,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class PatternTrailPage extends StatefulWidget {
  final int startLevel;

  const PatternTrailPage({super.key, this.startLevel = 1});

  @override
  State<PatternTrailPage> createState() => _PatternTrailPageState();
}

class _PatternTrailPageState extends State<PatternTrailPage>
    with TickerProviderStateMixin {

  late _GameState _game;
  DateTime?       _gameStartTime;
  bool            _resultSubmitted = false;

  // ── Per-dot visual state ─────────────────────────────────────────────────
  int?      _highlightedDot;
  final Set<int> _correctlyTapped = {};
  int?      _feedbackDot;
  bool      _feedbackCorrect = false;
  bool      _inputLocked     = false;

  // ── Animation controllers ────────────────────────────────────────────────
  late final List<AnimationController> _dotCtrl;
  late final List<Animation<double>>   _dotGlow;

  late final AnimationController _gameOverCtrl;
  late final Animation<double>   _gameOverFade;

  late final AnimationController _levelCompleteCtrl;
  late final Animation<double>   _levelCompleteScale;

  late final AnimationController _cdCtrl;
  late final Animation<double>   _cdScale;

  @override
  void initState() {
    super.initState();
    _game = _GameState.initial(widget.startLevel);

    _dotCtrl = List.generate(
      16,
      (_) => AnimationController(
          vsync: this, duration: const Duration(milliseconds: 220)),
    );
    _dotGlow = _dotCtrl
        .map((c) => Tween<double>(begin: 0.0, end: 1.0)
            .animate(CurvedAnimation(parent: c, curve: Curves.easeOut)))
        .toList();

    _gameOverCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _gameOverFade =
        CurvedAnimation(parent: _gameOverCtrl, curve: Curves.easeOut);

    _levelCompleteCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _levelCompleteScale = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _levelCompleteCtrl, curve: Curves.elasticOut));

    _cdCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _cdScale = Tween<double>(begin: 0.75, end: 1.0).animate(
        CurvedAnimation(parent: _cdCtrl, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    for (final c in _dotCtrl) c.dispose();
    _gameOverCtrl.dispose();
    _levelCompleteCtrl.dispose();
    _cdCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Game flow
  // ─────────────────────────────────────────────────────────────────────────

  void _startGame() {
    HapticFeedback.mediumImpact();
    _resultSubmitted = false;
    for (final c in _dotCtrl) { c.stop(); c.reset(); }
    setState(() {
      _game = _GameState.initial(widget.startLevel).copyWith(
        phase:     _Phase.countdown,
        countdown: 3,
      );
      _highlightedDot = null;
      _correctlyTapped.clear();
      _feedbackDot = null;
      _inputLocked = false;
    });
    _runCountdown();
  }

  Future<void> _runCountdown() async {
    for (int i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() => _game = _game.copyWith(countdown: i));
      _cdCtrl.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 850));
    }
    if (!mounted) return;
    _gameStartTime = DateTime.now();
    _startRound();
  }

  void _startRound() {
    for (final c in _dotCtrl) { c.stop(); c.reset(); }
    final seq = _generateSequence(_game.sequenceLength, _game.dotCount);
    setState(() {
      _game = _game.copyWith(
        phase:          _Phase.showing,
        sequence:       seq,
        playerProgress: 0,
      );
      _correctlyTapped.clear();
      _feedbackDot = null;
      _inputLocked = true;
    });
    _playSequence(seq);
  }

  List<int> _generateSequence(int length, int dotCount) {
    final rng = math.Random();
    final seq = <int>[];
    for (int i = 0; i < length; i++) {
      int next;
      do {
        next = rng.nextInt(dotCount);
      } while (seq.isNotEmpty && next == seq.last);
      seq.add(next);
    }
    return seq;
  }

  Future<void> _playSequence(List<int> seq) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final dotOnMs = _dotOnMsForLevel(_game.level);

    for (int i = 0; i < seq.length; i++) {
      if (!mounted) return;
      final idx = seq[i];

      setState(() => _highlightedDot = idx);
      _dotCtrl[idx].forward(from: 0);
      HapticFeedback.selectionClick();

      await Future.delayed(Duration(milliseconds: dotOnMs));
      if (!mounted) return;

      setState(() => _highlightedDot = null);
      _dotCtrl[idx].reverse();

      await Future.delayed(const Duration(milliseconds: 160));
    }

    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    setState(() {
      _game        = _game.copyWith(phase: _Phase.input);
      _inputLocked = false;
    });
  }

  void _onDotTap(int index) {
    if (_game.phase != _Phase.input || _inputLocked) return;

    HapticFeedback.selectionClick();
    final expected    = _game.sequence[_game.playerProgress];
    final correct     = index == expected;
    final newProgress = _game.playerProgress + 1;

    if (correct) {
      _dotCtrl[index].forward(from: 0);
      setState(() {
        _correctlyTapped.add(index);
        _feedbackDot     = index;
        _feedbackCorrect = true;
        _game            = _game.copyWith(playerProgress: newProgress);
      });

      if (newProgress >= _game.sequence.length) {
        // ── Sequence complete → level complete ────────────────────────────
        _inputLocked = true;
        Future.delayed(const Duration(milliseconds: 480), () async {
          if (!mounted) return;
          setState(() => _game = _game.copyWith(
            score: _game.score + _game.roundPoints,
            phase: _Phase.levelComplete,
          ));
          _levelCompleteCtrl.forward(from: 0);
          HapticFeedback.heavyImpact();

          if (!_resultSubmitted) {
            _resultSubmitted = true;
            await GameProgressService.unlockUpToLevel('pattern_trail', _game.level + 1);
            await _submitResult(completed: true);
          }

          await Future.delayed(const Duration(milliseconds: 2000));
          if (mounted) Navigator.pop(context);
        });
      } else {
        Future.delayed(const Duration(milliseconds: 340), () {
          if (mounted) {
            setState(() => _feedbackDot = null);
            _dotCtrl[index].reverse();
          }
        });
      }
    } else {
      // ── Wrong tap → lose a life ──────────────────────────────────────────
      HapticFeedback.heavyImpact();
      _dotCtrl[index].forward(from: 0);
      final newLives = _game.lives - 1;
      setState(() {
        _feedbackDot     = index;
        _feedbackCorrect = false;
        _inputLocked     = true;
        _game            = _game.copyWith(
          lives:    newLives,
          mistakes: _game.mistakes + 1,
        );
      });

      Future.delayed(const Duration(milliseconds: 750), () {
        if (!mounted) return;
        _dotCtrl[index].reverse();
        setState(() => _feedbackDot = null);

        if (newLives <= 0) {
          _endGame();
        } else {
          // Replay the same sequence
          setState(() {
            _correctlyTapped.clear();
            _game = _game.copyWith(phase: _Phase.showing, playerProgress: 0);
          });
          _playSequence(_game.sequence);
        }
      });
    }
  }

  void _endGame() {
    setState(() => _game = _game.copyWith(phase: _Phase.gameOver));
    _gameOverCtrl.forward(from: 0);
    if (!_resultSubmitted) {
      _resultSubmitted = true;
      _submitResult(completed: false);
    }
  }

  Future<void> _submitResult({required bool completed}) async {
    final timePlayed = _gameStartTime != null
        ? DateTime.now().difference(_gameStartTime!).inSeconds
        : 0;
    final double accuracyFactor = (1.0 - (_game.mistakes * 0.08).clamp(0.0, 1.0));
    final int normalizedScore = (_game.level * 60 + accuracyFactor * 200).round().clamp(0, 1000);
    final double localFocusPoints =
        (normalizedScore / 60.0 * accuracyFactor).clamp(1.0, 15.0);

    final result = await GameService.submitResult(
      gameType:          'pattern_trail',
      score:             normalizedScore,
      timePlayedSeconds: timePlayed,
      completed:         completed,
      levelReached:      _game.level,
      mistakes:          _game.mistakes,
    );

    if (!mounted) return;

    final double pointsToAdd = (result != null && result.focusScoreGained > 0)
        ? result.focusScoreGained
        : localFocusPoints;

    context.read<DailyScoreProvider>().addPoints(pointsToAdd);
    ScoreGainToast.show(context, pointsToAdd, source: 'Pattern Trail');
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
        final playing =
            _game.phase != _Phase.idle && _game.phase != _Phase.gameOver &&
            _game.phase != _Phase.levelComplete;
        if (playing && !_resultSubmitted) {
          _resultSubmitted = true;
          await _submitResult(completed: false);
        }
        if (mounted) Navigator.pop(context);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: _kBg,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final showStats =
        _game.phase != _Phase.idle && _game.phase != _Phase.gameOver;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          _BackButton(onTap: () => Navigator.pop(context)),
          const Spacer(),
          if (showStats) ...[
            _LevelScoreChip(level: _game.level, score: _game.score),
            const SizedBox(width: 10),
          ],
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  // ── Body router ──────────────────────────────────────────────────────────

  Widget _buildBody() {
    switch (_game.phase) {
      case _Phase.idle:
        return _buildIdleScreen();
      case _Phase.countdown:
        return _buildCountdownScreen();
      case _Phase.showing:
      case _Phase.input:
        return _buildGameScreen();
      case _Phase.levelComplete:
        return _buildLevelCompleteScreen();
      case _Phase.gameOver:
        return FadeTransition(
            opacity: _gameOverFade, child: _buildGameOverScreen());
    }
  }

  // ── Idle screen ──────────────────────────────────────────────────────────

  Widget _buildIdleScreen() {
    final gs = _game.gridSize;
    final seqLen = _game.sequenceLength;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        children: [
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                _kAccent.withOpacity(0.28),
                _kAccent.withOpacity(0.04),
              ]),
              border:
                  Border.all(color: _kAccent.withOpacity(0.35), width: 1.5),
            ),
            child: const Icon(Icons.timeline_rounded, color: _kAccent, size: 42),
          ),
          const SizedBox(height: 18),
          const Text('Pattern Trail',
              style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
          const SizedBox(height: 10),
          Text(
            'Watch the dots light up one by one.\nTap them back in the exact same order!',
            textAlign: TextAlign.center,
            style: TextStyle(color: _kMuted, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 18),

          // Level info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _InfoChip(label: 'Level', value: '${widget.startLevel}', color: _kAccent),
                    _InfoChip(label: 'Grid', value: '${gs}×$gs', color: _kGold),
                    _InfoChip(label: 'Sequence', value: '$seqLen dots', color: AppColors.onTertiaryContainer),
                    _InfoChip(label: 'Lives', value: '3', color: _kWrong),
                  ],
                ),
                const SizedBox(height: 14),
                _PreviewDotGrid(gridSize: gs),
              ],
            ),
          ),
          const SizedBox(height: 30),

          GestureDetector(
            onTap: _startGame,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.primary.withOpacity(0.38),
                      blurRadius: 24,
                      offset: const Offset(0, 10)),
                ],
              ),
              child: const Center(
                child: Text('Start Level',
                    style: TextStyle(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        letterSpacing: 0.6)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Countdown ─────────────────────────────────────────────────────────────

  Widget _buildCountdownScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _cdScale,
            child: Text('${_game.countdown}',
                style: const TextStyle(
                    color: _kAccent,
                    fontSize: 96,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -4)),
          ),
          const SizedBox(height: 8),
          const Text('Get ready…',
              style: TextStyle(color: _kMuted, fontSize: 16)),
        ],
      ),
    );
  }

  // ── Active game screen ────────────────────────────────────────────────────

  Widget _buildGameScreen() {
    final gs        = _game.gridSize;
    final isShowing = _game.phase == _Phase.showing;
    final progress  = _game.playerProgress;
    final seqLen    = _game.sequence.length;

    return Column(
      children: [
        const SizedBox(height: 16),

        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: Text(
            isShowing ? 'Watch the sequence…' : 'Tap ${progress + 1} of $seqLen',
            key: ValueKey('$isShowing$progress'),
            style: const TextStyle(
                color: _kMuted, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 10),

        if (seqLen > 0)
          _SequenceProgressBar(
            length:   seqLen,
            done:     progress,
            isShowing: isShowing,
          ),

        const SizedBox(height: 8),

        // Lives row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) => Padding(
            padding: const EdgeInsets.only(left: 3),
            child: Icon(
              i < _game.lives
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: i < _game.lives ? _kWrong : AppColors.outlineVariant,
              size: 18,
            ),
          )),
        ),

        const SizedBox(height: 12),

        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AspectRatio(
                aspectRatio: 1,
                child: _buildDotGrid(gs),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildDotGrid(int gs) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:    gs,
        mainAxisSpacing:   gs == 3 ? 18 : 13,
        crossAxisSpacing:  gs == 3 ? 18 : 13,
      ),
      itemCount: gs * gs,
      itemBuilder: (_, index) => _buildDot(index),
    );
  }

  Widget _buildDot(int index) {
    final isHighlighted   = _highlightedDot == index;
    final isDoneTapped    = _correctlyTapped.contains(index);
    final isFeedback      = _feedbackDot == index;

    final Color dotColor;
    final Color borderColor;
    final List<BoxShadow> shadows;

    if (isFeedback) {
      final c = _feedbackCorrect ? _kCorrect : _kWrong;
      dotColor    = c.withOpacity(0.88);
      borderColor = c;
      shadows     = [BoxShadow(color: c.withOpacity(0.50), blurRadius: 20, spreadRadius: 2)];
    } else if (isHighlighted) {
      dotColor    = _kAccent.withOpacity(0.90);
      borderColor = _kAccent;
      shadows     = [BoxShadow(color: _kAccent.withOpacity(0.50), blurRadius: 20, spreadRadius: 2)];
    } else if (isDoneTapped) {
      dotColor    = _kAccent.withOpacity(0.22);
      borderColor = _kAccent.withOpacity(0.45);
      shadows     = [];
    } else {
      dotColor    = _kCard;
      borderColor = _kBorder;
      shadows     = [];
    }

    return GestureDetector(
      onTap: () => _onDotTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          shape:     BoxShape.circle,
          color:     dotColor,
          border:    Border.all(color: borderColor, width: 2.0),
          boxShadow: shadows,
        ),
      ),
    );
  }

  // ── Level complete screen ─────────────────────────────────────────────────

  Widget _buildLevelCompleteScreen() {
    return Center(
      child: ScaleTransition(
        scale: _levelCompleteScale,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryFixed,
                boxShadow: [
                  BoxShadow(
                      color: _kGold.withOpacity(0.45),
                      blurRadius: 36,
                      spreadRadius: 4),
                ],
              ),
              child: const Icon(Icons.star_rounded,
                  color: AppColors.primary, size: 46),
            ),
            const SizedBox(height: 20),
            const Text('Level Complete!',
                style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5)),
            const SizedBox(height: 8),
            Text('Level ${widget.startLevel} cleared',
                style: const TextStyle(color: _kMuted, fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              'Unlocked Level ${widget.startLevel + 1}!',
              style: const TextStyle(
                  color: _kAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // ── Game over screen ──────────────────────────────────────────────────────

  Widget _buildGameOverScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kWrong.withOpacity(0.10),
                border:
                    Border.all(color: _kWrong.withOpacity(0.30), width: 1.5),
              ),
              child: const Icon(Icons.timeline_rounded,
                  color: _kWrong, size: 42),
            ),
            const SizedBox(height: 20),
            const Text('Game Over',
                style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5)),
            const SizedBox(height: 6),
            Text('Out of lives on Level ${widget.startLevel}',
                style: const TextStyle(color: _kMuted, fontSize: 14)),
            const SizedBox(height: 28),
            _StatRow(
                label: 'Score',
                value: '${_game.score} pts',
                valueColor: _kAccent),
            const SizedBox(height: 8),
            _StatRow(
                label: 'Sequence Length',
                value: '${_game.sequenceLength} dots',
                valueColor: AppColors.onTertiaryContainer),
            const SizedBox(height: 8),
            _StatRow(
                label: 'Mistakes',
                value: '${_game.mistakes}',
                valueColor: _kWrong),
            const SizedBox(height: 44),
            _PrimaryButton(label: 'Try Again', onTap: _startGame),
            const SizedBox(height: 12),
            _SecondaryButton(
                label: 'Exit', onTap: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info chip
// ─────────────────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  const _InfoChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: _kMuted, fontSize: 10)),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Preview dot grid  (idle screen)
// ─────────────────────────────────────────────────────────────────────────────

class _PreviewDotGrid extends StatelessWidget {
  final int gridSize;
  const _PreviewDotGrid({required this.gridSize});

  @override
  Widget build(BuildContext context) {
    final highlights = gridSize == 3
        ? const {1: '1', 7: '2', 3: '3'}
        : const {2: '1', 13: '2', 5: '3', 10: '4'};

    return SizedBox(
      height: gridSize == 3 ? 108 : 128,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:   gridSize,
          mainAxisSpacing:  8,
          crossAxisSpacing: 8,
        ),
        itemCount: gridSize * gridSize,
        itemBuilder: (_, i) {
          final label = highlights[i];
          final lit   = label != null;
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: lit ? _kAccent.withOpacity(0.85) : _kCard,
              border: Border.all(
                  color: lit ? _kAccent : _kBorder, width: 1.5),
              boxShadow: lit
                  ? [BoxShadow(
                      color: _kAccent.withOpacity(0.45), blurRadius: 10)]
                  : null,
            ),
            child: lit
                ? Center(
                    child: Text(label,
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800)),
                  )
                : null,
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sequence progress bar
// ─────────────────────────────────────────────────────────────────────────────

class _SequenceProgressBar extends StatelessWidget {
  final int  length;
  final int  done;
  final bool isShowing;

  const _SequenceProgressBar({
    required this.length,
    required this.done,
    required this.isShowing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (i) {
        final isDone    = i < done;
        final isCurrent = !isShowing && i == done;
        final size      = isDone || isCurrent ? 10.0 : 7.0;
        final color     = isDone    ? _kAccent
                        : isCurrent ? _kGold
                        : _kBorder;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3.5),
          width:  size,
          height: size,
          decoration: BoxDecoration(
            shape:     BoxShape.circle,
            color:     color,
            boxShadow: isCurrent
                ? [BoxShadow(
                    color: _kGold.withOpacity(0.60), blurRadius: 8)]
                : null,
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.onPrimary, size: 16),
        ),
      );
}

class _LevelScoreChip extends StatelessWidget {
  final int level;
  final int score;
  const _LevelScoreChip({required this.level, required this.score});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: _kAccent.withOpacity(0.20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Lv $level',
                style: const TextStyle(
                    color: _kAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.star_rounded, color: _kGold, size: 14),
          const SizedBox(width: 4),
          Text('$score',
              style: const TextStyle(
                  color: AppColors.onPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ]),
      );
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color  valueColor;
  const _StatRow(
      {required this.label,
      required this.value,
      required this.valueColor});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: _kMuted, fontSize: 14)),
          Text(value,
              style: TextStyle(
                  color: valueColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ],
      );
}

class _PrimaryButton extends StatelessWidget {
  final String       label;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withOpacity(0.38),
                  blurRadius: 22,
                  offset: const Offset(0, 9)),
            ],
          ),
          child: Center(
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: 0.3)),
          ),
        ),
      );
}

class _SecondaryButton extends StatelessWidget {
  final String       label;
  final VoidCallback onTap;
  const _SecondaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorder),
          ),
          child: Center(
            child: Text(label,
                style: const TextStyle(
                    color: _kMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
          ),
        ),
      );
}
