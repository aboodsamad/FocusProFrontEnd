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
const _kCard    = AppColors.surfaceContainerLowest;
const _kBorder  = AppColors.outlineVariant;
const _kAccent  = AppColors.secondary;
const _kGold    = AppColors.primaryFixed;
const _kWrong   = AppColors.error;
const _kCorrect = AppColors.secondary;
const _kMuted   = AppColors.onSurfaceVariant;

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

enum _Phase { idle, countdown, playing, levelComplete }

enum _Shape { circle, square, triangle, star }

class _CardData {
  final _Shape shape;
  final Color  color;
  final String colorName;

  const _CardData({
    required this.shape,
    required this.color,
    required this.colorName,
  });
}

/// Level-based match rule:
///   Levels 1–3  → color must match
///   Levels 4–7  → shape must match
///   Levels 8–10 → both color and shape must match
bool _cardMatches(_CardData a, _CardData b, int level) {
  if (level <= 3) return a.colorName == b.colorName;
  if (level <= 7) return a.shape == b.shape;
  return a.colorName == b.colorName && a.shape == b.shape;
}

String _matchLabel(int level) {
  if (level <= 3) return 'COLOR';
  if (level <= 7) return 'SHAPE';
  return 'COLOR + SHAPE';
}

const _kShapeColors = [
  (name: 'Red',    color: Color(0xFFEF4444)),
  (name: 'Blue',   color: Color(0xFF3B82F6)),
  (name: 'Green',  color: Color(0xFF10B981)),
  (name: 'Yellow', color: Color(0xFFFFD166)),
  (name: 'Purple', color: Color(0xFFA78BFA)),
  (name: 'Orange', color: Color(0xFFF97316)),
];

_CardData _randomCard([math.Random? rng]) {
  rng ??= math.Random();
  final col   = _kShapeColors[rng.nextInt(_kShapeColors.length)];
  final shape = _Shape.values[rng.nextInt(_Shape.values.length)];
  return _CardData(shape: shape, color: col.color, colorName: col.name);
}

class _GameState {
  final _Phase     phase;
  final int        level;
  final int        score;
  final int        streak;
  final int        bestStreak;
  final int        countdown;
  final int        mistakes;
  final int        correct;
  final _CardData? currentCard;
  final _CardData? previousCard;

  const _GameState({
    required this.phase,
    required this.level,
    required this.score,
    required this.streak,
    required this.bestStreak,
    required this.countdown,
    required this.mistakes,
    required this.correct,
    this.currentCard,
    this.previousCard,
  });

  factory _GameState.initial(int level) => _GameState(
    phase:      _Phase.idle,
    level:      level,
    score:      0,
    streak:     0,
    bestStreak: 0,
    countdown:  3,
    mistakes:   0,
    correct:    0,
  );

  bool? get isMatch {
    if (currentCard == null || previousCard == null) return null;
    return _cardMatches(currentCard!, previousCard!, level);
  }

  int get accuracy {
    final total = correct + mistakes;
    if (total == 0) return 0;
    return (correct / total * 100).round();
  }

  _GameState copyWith({
    _Phase?    phase,
    int?       level,
    int?       score,
    int?       streak,
    int?       bestStreak,
    int?       countdown,
    int?       mistakes,
    int?       correct,
    _CardData? currentCard,
    _CardData? previousCard,
  }) =>
      _GameState(
        phase:        phase        ?? this.phase,
        level:        level        ?? this.level,
        score:        score        ?? this.score,
        streak:       streak       ?? this.streak,
        bestStreak:   bestStreak   ?? this.bestStreak,
        countdown:    countdown    ?? this.countdown,
        mistakes:     mistakes     ?? this.mistakes,
        correct:      correct      ?? this.correct,
        currentCard:  currentCard  ?? this.currentCard,
        previousCard: previousCard ?? this.previousCard,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class SpeedMatchPage extends StatefulWidget {
  final int startLevel;
  const SpeedMatchPage({super.key, this.startLevel = 1});

  @override
  State<SpeedMatchPage> createState() => _SpeedMatchPageState();
}

class _SpeedMatchPageState extends State<SpeedMatchPage>
    with TickerProviderStateMixin {

  late _GameState _game;
  DateTime?       _gameStartTime;
  bool            _resultSubmitted = false;

  static int _bestScore = 0;

  // ── 60-second session timer ──────────────────────────────────────────────
  Timer? _sessionTimer;
  int    _sessionSecondsLeft = 60;

  // ── Per-card shrinking timer ─────────────────────────────────────────────
  late AnimationController _cardTimerCtrl;
  Timer?                   _cardTimeoutTimer;

  // ── Feedback flash ───────────────────────────────────────────────────────
  bool                    _feedbackShowing   = false;
  bool                    _lastAnswerCorrect = false;
  late AnimationController _feedbackCtrl;
  late Animation<double>  _feedbackOpacity;

  // ── Level-complete fade ──────────────────────────────────────────────────
  late AnimationController _levelCompleteCtrl;
  late Animation<double>  _levelCompleteFade;

  // ── Countdown pulse ──────────────────────────────────────────────────────
  late AnimationController _cdCtrl;
  late Animation<double>  _cdScale;

  @override
  void initState() {
    super.initState();
    _game = _GameState.initial(widget.startLevel);

    _cardTimerCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3));

    _feedbackCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _feedbackOpacity = CurvedAnimation(
        parent: _feedbackCtrl, curve: Curves.easeOut);

    _levelCompleteCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _levelCompleteFade = CurvedAnimation(
        parent: _levelCompleteCtrl, curve: Curves.easeOut);

    _cdCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _cdScale = Tween<double>(begin: 0.75, end: 1.0).animate(
        CurvedAnimation(parent: _cdCtrl, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _cardTimerCtrl.dispose();
    _feedbackCtrl.dispose();
    _levelCompleteCtrl.dispose();
    _cdCtrl.dispose();
    _cardTimeoutTimer?.cancel();
    _sessionTimer?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Per-card timer duration — base shortens with level, further reduced by score
  // ─────────────────────────────────────────────────────────────────────────

  Duration _cardDuration() {
    final baseSecs = (3.0 - (widget.startLevel - 1) * 0.22).clamp(0.8, 3.0);
    final reduced  = (baseSecs - _game.score * 0.04).clamp(0.6, baseSecs);
    return Duration(milliseconds: (reduced * 1000).round());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Game flow
  // ─────────────────────────────────────────────────────────────────────────

  void _startGame() {
    HapticFeedback.mediumImpact();
    _cardTimeoutTimer?.cancel();
    _cardTimerCtrl.stop();
    _resultSubmitted = false;
    setState(() {
      _game = _GameState.initial(widget.startLevel)
          .copyWith(phase: _Phase.countdown, countdown: 3);
      _feedbackShowing = false;
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
    _beginPlaying();
  }

  void _beginPlaying() {
    _gameStartTime = DateTime.now();
    _sessionSecondsLeft = 60;
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
    final firstCard = _randomCard();
    setState(() {
      _game = _game.copyWith(
        phase:       _Phase.playing,
        currentCard: firstCard,
      );
      _feedbackShowing = false;
    });
    _startCardTimer();
  }

  void _startCardTimer() {
    _cardTimeoutTimer?.cancel();
    final dur = _cardDuration();
    _cardTimerCtrl.duration = dur;
    _cardTimerCtrl.forward(from: 0);
    _cardTimeoutTimer = Timer(dur, _onCardTimeout);
  }

  void _onCardTimeout() {
    if (_game.phase != _Phase.playing || _feedbackShowing) return;
    if (_game.previousCard == null) {
      _nextCard();
    } else {
      _handleAnswer(tappedYes: null, timedOut: true);
    }
  }

  void _onYes() {
    if (_game.phase != _Phase.playing || _feedbackShowing) return;
    if (_game.previousCard == null) return;
    HapticFeedback.lightImpact();
    _handleAnswer(tappedYes: true);
  }

  void _onNo() {
    if (_game.phase != _Phase.playing || _feedbackShowing) return;
    if (_game.previousCard == null) return;
    HapticFeedback.lightImpact();
    _handleAnswer(tappedYes: false);
  }

  void _handleAnswer({required bool? tappedYes, bool timedOut = false}) {
    _cardTimeoutTimer?.cancel();
    _cardTimerCtrl.stop();

    final correct = !timedOut && (tappedYes == _game.isMatch);

    setState(() {
      _feedbackShowing   = true;
      _lastAnswerCorrect = correct;
    });
    _feedbackCtrl.forward(from: 0);

    if (correct) {
      final newStreak = _game.streak + 1;
      setState(() => _game = _game.copyWith(
        score:      _game.score + 1,
        streak:     newStreak,
        bestStreak: newStreak > _game.bestStreak ? newStreak : _game.bestStreak,
        correct:    _game.correct + 1,
      ));
      Future.delayed(const Duration(milliseconds: 380), () {
        if (mounted) _nextCard();
      });
    } else {
      HapticFeedback.heavyImpact();
      setState(() => _game = _game.copyWith(
        streak:   0,
        mistakes: _game.mistakes + 1,
      ));
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _nextCard();
      });
    }
  }

  void _nextCard() {
    if (!mounted) return;
    setState(() {
      _game = _game.copyWith(
        previousCard: _game.currentCard,
        currentCard:  _randomCard(),
      );
      _feedbackShowing = false;
    });
    _startCardTimer();
  }

  void _endGame() {
    _sessionTimer?.cancel();
    _cardTimeoutTimer?.cancel();
    _cardTimerCtrl.stop();
    if (_game.score > _bestScore) _bestScore = _game.score;
    setState(() => _game = _game.copyWith(phase: _Phase.levelComplete));
    _levelCompleteCtrl.forward(from: 0);
    _doLevelComplete();
  }

  Future<void> _doLevelComplete() async {
    if (!_resultSubmitted) {
      _resultSubmitted = true;
      final nextLevel = widget.startLevel + 1;
      await GameProgressService.unlockUpToLevel('speed_match', nextLevel);
      await _submitResult();
    }
    await Future.delayed(const Duration(milliseconds: 2400));
    if (mounted) Navigator.pop(context);
  }

  Future<void> _submitResult() async {
    final timePlayed = _gameStartTime != null
        ? DateTime.now().difference(_gameStartTime!).inSeconds
        : 0;
    final int total = _game.correct + _game.mistakes;
    final double accuracyRate = total > 0 ? _game.correct / total : 0.5;
    final int normalizedScore =
        (accuracyRate * widget.startLevel * 100).round().clamp(0, 1000);
    final result = await GameService.submitResult(
      gameType:          'speed_match',
      score:             normalizedScore,
      timePlayedSeconds: timePlayed,
      completed:         true,
      levelReached:      widget.startLevel,
      mistakes:          _game.mistakes,
    );
    if (result != null && mounted) {
      context.read<DailyScoreProvider>().addPoints(result.focusScoreGained);
      ScoreGainToast.show(context, result.focusScoreGained, source: 'Speed Match');
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
        if (_game.phase == _Phase.playing && !_resultSubmitted) {
          _sessionTimer?.cancel();
          _cardTimeoutTimer?.cancel();
          _cardTimerCtrl.stop();
          _resultSubmitted = true;
          await _submitResult();
        }
        if (mounted) Navigator.pop(context);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: _kBg,
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    _buildHeader(),
                    if (_game.phase == _Phase.playing) _buildCardTimerBar(),
                    Expanded(child: _buildBody()),
                  ],
                ),
                if (_feedbackShowing) _buildFeedbackOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Feedback overlay ─────────────────────────────────────────────────────

  Widget _buildFeedbackOverlay() {
    final color = _lastAnswerCorrect ? _kCorrect : _kWrong;
    return IgnorePointer(
      child: FadeTransition(
        opacity: _feedbackOpacity,
        child: Container(color: color.withOpacity(0.10)),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final isPlaying = _game.phase == _Phase.playing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          _BackButton(onTap: () => Navigator.maybePop(context)),
          const Spacer(),
          if (isPlaying) ...[
            _ScoreChip(score: _game.score, streak: _game.streak),
            const SizedBox(width: 10),
            _SessionTimerChip(secondsLeft: _sessionSecondsLeft),
          ] else
            const SizedBox(width: 40),
        ],
      ),
    );
  }

  // ── Per-card shrinking timer bar ─────────────────────────────────────────

  Widget _buildCardTimerBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: AnimatedBuilder(
        animation: _cardTimerCtrl,
        builder: (_, __) {
          final fraction = (1.0 - _cardTimerCtrl.value).clamp(0.0, 1.0);
          final barColor = fraction > 0.55 ? _kAccent
              : fraction > 0.28 ? _kGold
              : _kWrong;
          return ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: AppColors.surfaceContainerLow,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          );
        },
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
      case _Phase.playing:
        return _buildPlayScreen();
      case _Phase.levelComplete:
        return FadeTransition(
            opacity: _levelCompleteFade, child: _buildLevelCompleteScreen());
    }
  }

  // ── Idle screen ──────────────────────────────────────────────────────────

  Widget _buildIdleScreen() {
    final criterion = _matchLabel(widget.startLevel);
    final cardMs    = (3.0 - (widget.startLevel - 1) * 0.22).clamp(0.8, 3.0);
    final cardSec   = cardMs.toStringAsFixed(1);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        children: [
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                  colors: [_kAccent.withOpacity(0.28), _kAccent.withOpacity(0.04)]),
              border: Border.all(color: _kAccent.withOpacity(0.35), width: 1.5),
            ),
            child: const Icon(Icons.bolt_rounded, color: _kAccent, size: 42),
          ),
          const SizedBox(height: 18),
          const Text('Speed Match',
              style: TextStyle(color: AppColors.onSurface, fontSize: 28,
                  fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 10),
          Text(
            'Does this card match the previous one?\nTap YES or NO before time runs out!',
            textAlign: TextAlign.center,
            style: TextStyle(color: _kMuted, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 18),

          // How-to example
          Container(
            padding: const EdgeInsets.all(16),
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
                    _ExampleCard(
                        shape: _Shape.circle,
                        color: const Color(0xFFEF4444),
                        label: 'Previous'),
                    const Icon(Icons.arrow_forward_rounded,
                        color: _kMuted, size: 20),
                    _ExampleCard(
                        shape: _Shape.circle,
                        color: const Color(0xFFEF4444),
                        label: 'Current'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: _kCorrect, size: 16),
                    const SizedBox(width: 6),
                    Text('Match by $criterion → tap YES',
                        style: const TextStyle(color: _kMuted, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Best score badge
          if (_bestScore > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _kGold.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kGold.withOpacity(0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.emoji_events_rounded, color: _kGold, size: 16),
                const SizedBox(width: 6),
                Text('Best: $_bestScore cards',
                    style: const TextStyle(color: _kGold, fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 20),
          ] else
            const SizedBox(height: 4),

          // Level info chips
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoChip(icon: Icons.bar_chart_rounded,
                  label: 'Level ${widget.startLevel}'),
              _InfoChip(icon: Icons.compare_arrows_rounded,
                  label: 'Match: $criterion'),
              _InfoChip(icon: Icons.speed_rounded,
                  label: '${cardSec}s per card'),
              _InfoChip(icon: Icons.timer_rounded, label: '60s session'),
            ],
          ),
          const SizedBox(height: 30),

          // Start button
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
                child: Text('Start',
                    style: TextStyle(color: AppColors.onPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 17, letterSpacing: 0.6)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Countdown screen ─────────────────────────────────────────────────────

  Widget _buildCountdownScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _cdScale,
            child: Text(
              '${_game.countdown}',
              style: const TextStyle(
                  color: _kAccent, fontSize: 96,
                  fontWeight: FontWeight.w800, letterSpacing: -4),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Get ready…',
              style: TextStyle(color: _kMuted, fontSize: 16)),
        ],
      ),
    );
  }

  // ── Play screen ──────────────────────────────────────────────────────────

  Widget _buildPlayScreen() {
    final card        = _game.currentCard;
    if (card == null) return const SizedBox.shrink();
    final isFirstCard = _game.previousCard == null;

    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Match by: ', style: TextStyle(color: _kMuted, fontSize: 13)),
            Text(
              _matchLabel(widget.startLevel),
              style: const TextStyle(
                  color: _kAccent, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isFirstCard ? 'Memorise this card!' : 'Does it match?',
                  style: TextStyle(
                      color: _kMuted, fontSize: 12, letterSpacing: 0.3),
                ),
                const SizedBox(height: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) {
                    final scale = Tween<double>(begin: 0.82, end: 1.0).animate(
                        CurvedAnimation(
                            parent: anim, curve: Curves.elasticOut));
                    return ScaleTransition(
                        scale: scale,
                        child: FadeTransition(opacity: anim, child: child));
                  },
                  child: _ShapeCard(
                    key: ValueKey(_game.score * 100 + card.shape.index),
                    card: card,
                    size: 136,
                    feedbackColor: _feedbackShowing
                        ? (_lastAnswerCorrect ? _kCorrect : _kWrong)
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: isFirstCard
              ? Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _kBorder),
                  ),
                  child: const Center(
                    child: Text('Memorise this card!',
                        style: TextStyle(color: _kMuted, fontSize: 15,
                            fontWeight: FontWeight.w500)),
                  ),
                )
              : Row(
                  children: [
                    Expanded(
                      child: _AnswerButton(
                        label:   'YES',
                        color:   _kCorrect,
                        icon:    Icons.check_rounded,
                        onTap:   _onYes,
                        enabled: !_feedbackShowing,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AnswerButton(
                        label:   'NO',
                        color:   _kWrong,
                        icon:    Icons.close_rounded,
                        onTap:   _onNo,
                        enabled: !_feedbackShowing,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  // ── Level complete screen ────────────────────────────────────────────────

  Widget _buildLevelCompleteScreen() {
    final nextLevel  = widget.startLevel + 1;
    final isNewBest  = _game.score > 0 && _game.score >= _bestScore;
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
                color: _kAccent.withOpacity(0.12),
                border: Border.all(color: _kAccent.withOpacity(0.4), width: 1.5),
              ),
              child: const Icon(Icons.check_rounded, color: _kAccent, size: 44),
            ),
            const SizedBox(height: 20),
            const Text('Level Complete!',
                style: TextStyle(color: AppColors.onSurface, fontSize: 30,
                    fontWeight: FontWeight.w700, letterSpacing: -0.5)),
            const SizedBox(height: 8),
            Text('Level ${widget.startLevel} cleared',
                style: const TextStyle(color: _kMuted, fontSize: 15)),
            if (nextLevel <= 10) ...[
              const SizedBox(height: 4),
              Text('Unlocked Level $nextLevel!',
                  style: const TextStyle(color: _kAccent, fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ],
            if (isNewBest) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: _kGold.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kGold.withOpacity(0.4)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.emoji_events_rounded, color: _kGold, size: 14),
                  SizedBox(width: 5),
                  Text('New Best!',
                      style: TextStyle(color: _kGold, fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ],
            const SizedBox(height: 32),
            _StatRow(label: 'Cards Matched',
                value: '${_game.score}', valueColor: _kAccent),
            const SizedBox(height: 8),
            _StatRow(label: 'Best Streak',
                value: '×${_game.bestStreak}', valueColor: _kGold),
            const SizedBox(height: 8),
            _StatRow(label: 'Accuracy',
                value: '${_game.accuracy}%',
                valueColor: AppColors.onTertiaryContainer),
            const SizedBox(height: 8),
            _StatRow(label: 'Mistakes',
                value: '${_game.mistakes}', valueColor: _kWrong),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shape card widget
// ─────────────────────────────────────────────────────────────────────────────

class _ShapeCard extends StatelessWidget {
  final _CardData card;
  final double    size;
  final Color?    feedbackColor;

  const _ShapeCard({
    super.key,
    required this.card,
    required this.size,
    required this.feedbackColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasFeedback = feedbackColor != null;
    final borderColor = hasFeedback ? feedbackColor! : _kBorder;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: size + 36,
      height: size + 36,
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor.withOpacity(hasFeedback ? 0.85 : 1.0),
          width: hasFeedback ? 2.5 : 1.5,
        ),
        boxShadow: hasFeedback
            ? [
                BoxShadow(
                    color: feedbackColor!.withOpacity(0.28),
                    blurRadius: 22,
                    spreadRadius: 2),
              ]
            : null,
      ),
      child: Center(
        child: CustomPaint(
          size: Size(size, size),
          painter: _ShapePainter(shape: card.shape, color: card.color),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shape painter  (circle, square, triangle, star)
// ─────────────────────────────────────────────────────────────────────────────

class _ShapePainter extends CustomPainter {
  final _Shape shape;
  final Color  color;

  const _ShapePainter({required this.shape, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final glow = Paint()
      ..color = color.withOpacity(0.22)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);

    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    switch (shape) {
      case _Shape.circle:
        canvas.drawCircle(c, r * 0.98, glow);
        canvas.drawCircle(c, r * 0.78, fill);
        break;

      case _Shape.square:
        final s    = r * 1.32;
        final rect = Rect.fromCenter(center: c, width: s, height: s);
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(10)), glow);
        final inner = Rect.fromCenter(
            center: c, width: s * 0.84, height: s * 0.84);
        canvas.drawRRect(
            RRect.fromRectAndRadius(inner, const Radius.circular(8)), fill);
        break;

      case _Shape.triangle:
        final gPath = Path()
          ..moveTo(c.dx, c.dy - r * 1.02)
          ..lineTo(c.dx + r * 1.02, c.dy + r * 0.72)
          ..lineTo(c.dx - r * 1.02, c.dy + r * 0.72)
          ..close();
        final fPath = Path()
          ..moveTo(c.dx, c.dy - r * 0.86)
          ..lineTo(c.dx + r * 0.86, c.dy + r * 0.60)
          ..lineTo(c.dx - r * 0.86, c.dy + r * 0.60)
          ..close();
        canvas.drawPath(gPath, glow);
        canvas.drawPath(fPath, fill);
        break;

      case _Shape.star:
        canvas.drawPath(_starPath(c, r * 1.02, r * 0.42, 5), glow);
        canvas.drawPath(_starPath(c, r * 0.86, r * 0.36, 5), fill);
        break;
    }
  }

  Path _starPath(Offset center, double outerR, double innerR, int points) {
    final path = Path();
    for (int i = 0; i < points * 2; i++) {
      final angle = (i * math.pi / points) - math.pi / 2;
      final rad   = i.isEven ? outerR : innerR;
      final x     = center.dx + rad * math.cos(angle);
      final y     = center.dy + rad * math.sin(angle);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant _ShapePainter old) =>
      old.shape != shape || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Small example card for idle screen
// ─────────────────────────────────────────────────────────────────────────────

class _ExampleCard extends StatelessWidget {
  final _Shape shape;
  final Color  color;
  final String label;

  const _ExampleCard({
    required this.shape,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBorder),
            ),
            child: Center(
              child: CustomPaint(
                size: const Size(34, 34),
                painter: _ShapePainter(shape: shape, color: color),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: _kMuted, fontSize: 10)),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Answer button  (YES / NO)
// ─────────────────────────────────────────────────────────────────────────────

class _AnswerButton extends StatelessWidget {
  final String       label;
  final Color        color;
  final IconData     icon;
  final VoidCallback onTap;
  final bool         enabled;

  const _AnswerButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: enabled ? 1.0 : 0.45,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.40)),
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.14),
                    blurRadius: 16,
                    offset: const Offset(0, 6)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 8),
                Text(label,
                    style: TextStyle(
                        color: color, fontSize: 17,
                        fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              ],
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
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
              color: AppColors.onSurface, size: 16),
        ),
      );
}

class _ScoreChip extends StatelessWidget {
  final int score;
  final int streak;
  const _ScoreChip({required this.score, required this.streak});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.star_rounded, color: _kGold, size: 14),
          const SizedBox(width: 5),
          Text('$score',
              style: const TextStyle(color: AppColors.onSurface,
                  fontSize: 13, fontWeight: FontWeight.w700)),
          if (streak > 1) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _kAccent.withOpacity(0.20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('×$streak',
                  style: const TextStyle(color: _kAccent, fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
      );
}

class _SessionTimerChip extends StatelessWidget {
  final int secondsLeft;
  const _SessionTimerChip({required this.secondsLeft});

  @override
  Widget build(BuildContext context) {
    final fraction = (secondsLeft / 60).clamp(0.0, 1.0);
    final color = fraction > 0.5 ? _kAccent
        : fraction > 0.25 ? _kGold
        : _kWrong;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.timer_rounded, color: color, size: 14),
        const SizedBox(width: 5),
        Text('${secondsLeft}s',
            style: TextStyle(color: color, fontSize: 13,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: _kAccent, size: 14),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(color: AppColors.onSurface,
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color  valueColor;
  const _StatRow(
      {required this.label, required this.value, required this.valueColor});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: _kMuted, fontSize: 14)),
          Text(value,
              style: TextStyle(
                  color: valueColor, fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ],
      );
}
