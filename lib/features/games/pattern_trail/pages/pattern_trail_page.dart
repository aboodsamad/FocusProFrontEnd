import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../features/home/providers/user_provider.dart';
import '../../services/game_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design constants  (same palette as other games)
// ─────────────────────────────────────────────────────────────────────────────

const _kBg      = Color(0xFF06090F);
const _kCard    = Color(0xFF0F1624);
const _kBorder  = Color(0xFF1E2840);
const _kAccent  = Color(0xFF378ADD); // blue — matches registry colorValue
const _kGold    = Color(0xFFFFD166);
const _kWrong   = Color(0xFFFF5270);
const _kCorrect = Color(0xFF10B981);
const _kMuted   = Color(0xFF6B7A99);

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

enum _Phase { idle, countdown, showing, input, levelUp, gameOver }

enum PatternTrailDifficulty { easy, medium, hard }

class _GameState {
  final _Phase                  phase;
  final PatternTrailDifficulty  difficulty;
  final int                     level;
  final int                     sequenceLength;
  final List<int>               sequence;     // dot indices in playback order
  final int                     playerProgress; // correct taps so far
  final int                     score;
  final int                     lives;
  final int                     mistakes;
  final int                     countdown;

  const _GameState({
    required this.phase,
    required this.difficulty,
    required this.level,
    required this.sequenceLength,
    required this.sequence,
    required this.playerProgress,
    required this.score,
    required this.lives,
    required this.mistakes,
    required this.countdown,
  });

  factory _GameState.initial(PatternTrailDifficulty d) => _GameState(
        phase:          _Phase.idle,
        difficulty:     d,
        level:          1,
        sequenceLength: d == PatternTrailDifficulty.hard ? 4 : 3,
        sequence:       const [],
        playerProgress: 0,
        score:          0,
        lives:          3,
        mistakes:       0,
        countdown:      3,
      );

  // Grid is 3×3 on Easy, 4×4 on Medium/Hard
  int get gridSize => difficulty == PatternTrailDifficulty.easy ? 3 : 4;
  int get dotCount => gridSize * gridSize;

  // Points for completing the current sequence
  int get roundPoints => level * sequenceLength * 10;

  _GameState copyWith({
    _Phase?                  phase,
    PatternTrailDifficulty?  difficulty,
    int?                     level,
    int?                     sequenceLength,
    List<int>?               sequence,
    int?                     playerProgress,
    int?                     score,
    int?                     lives,
    int?                     mistakes,
    int?                     countdown,
  }) =>
      _GameState(
        phase:          phase          ?? this.phase,
        difficulty:     difficulty     ?? this.difficulty,
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
  const PatternTrailPage({super.key});

  @override
  State<PatternTrailPage> createState() => _PatternTrailPageState();
}

class _PatternTrailPageState extends State<PatternTrailPage>
    with TickerProviderStateMixin {

  late _GameState _game;
  DateTime?       _gameStartTime;

  static int _bestScore = 0;

  // ── Per-dot visual state ─────────────────────────────────────────────────
  int?      _highlightedDot;           // index of dot lit during showing
  final Set<int> _correctlyTapped = {}; // dots correctly tapped this round
  int?      _feedbackDot;              // dot currently flashing feedback
  bool      _feedbackCorrect = false;  // true = green, false = red
  bool      _inputLocked     = false;  // blocks taps during transitions

  // ── Animation controllers ────────────────────────────────────────────────
  // 16 controllers cover the max 4×4 grid; easy (3×3) uses only 0–8.
  late final List<AnimationController> _dotCtrl;
  late final List<Animation<double>>   _dotGlow;

  late final AnimationController _gameOverCtrl;
  late final Animation<double>   _gameOverFade;

  late final AnimationController _levelUpCtrl;
  late final Animation<double>   _levelUpScale;

  late final AnimationController _cdCtrl;
  late final Animation<double>   _cdScale;

  @override
  void initState() {
    super.initState();
    _game = _GameState.initial(PatternTrailDifficulty.medium);

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

    _levelUpCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _levelUpScale = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _levelUpCtrl, curve: Curves.elasticOut));

    _cdCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _cdScale = Tween<double>(begin: 0.75, end: 1.0).animate(
        CurvedAnimation(parent: _cdCtrl, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    for (final c in _dotCtrl) c.dispose();
    _gameOverCtrl.dispose();
    _levelUpCtrl.dispose();
    _cdCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Timing — dot-on duration shrinks as level increases
  // ─────────────────────────────────────────────────────────────────────────

  int _dotOnMs() {
    final base = _game.difficulty == PatternTrailDifficulty.easy   ? 800
               : _game.difficulty == PatternTrailDifficulty.medium ? 600
               : 440;
    return (base - (_game.level - 1) * 25).clamp(220, base);
  }

  static const int _dotOffMs = 160; // gap between dots

  // ─────────────────────────────────────────────────────────────────────────
  // Game flow
  // ─────────────────────────────────────────────────────────────────────────

  void _startGame() {
    HapticFeedback.mediumImpact();
    for (final c in _dotCtrl) { c.stop(); c.reset(); }
    setState(() {
      _game = _GameState.initial(_game.difficulty)
          .copyWith(phase: _Phase.countdown, countdown: 3);
      _highlightedDot = null;
      _correctlyTapped.clear();
      _feedbackDot    = null;
      _inputLocked    = false;
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

  // Build a random sequence, never repeating the same dot consecutively.
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
    // Brief pre-play pause so the UI can settle
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    for (int i = 0; i < seq.length; i++) {
      if (!mounted) return;
      final idx = seq[i];

      setState(() => _highlightedDot = idx);
      _dotCtrl[idx].forward(from: 0);
      HapticFeedback.selectionClick();

      await Future.delayed(Duration(milliseconds: _dotOnMs()));
      if (!mounted) return;

      setState(() => _highlightedDot = null);
      _dotCtrl[idx].reverse();

      await Future.delayed(const Duration(milliseconds: _dotOffMs));
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
        // ── Sequence complete → level up ───────────────────────────────────
        _inputLocked = true;
        final points = _game.roundPoints; // capture before incrementing
        Future.delayed(const Duration(milliseconds: 480), () {
          if (!mounted) return;
          setState(() => _game = _game.copyWith(
            score:          _game.score + points,
            level:          _game.level + 1,
            sequenceLength: _game.sequenceLength + 1,
            phase:          _Phase.levelUp,
          ));
          _levelUpCtrl.forward(from: 0);
          HapticFeedback.heavyImpact();
          Future.delayed(const Duration(milliseconds: 1900), () {
            if (mounted) _startRound();
          });
        });
      } else {
        // Clear the green flash after a short delay
        Future.delayed(const Duration(milliseconds: 340), () {
          if (mounted) {
            setState(() => _feedbackDot = null);
            _dotCtrl[index].reverse();
          }
        });
      }
    } else {
      // ── Wrong tap → lives down, replay same sequence ─────────────────────
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
          // Replay the same sequence from the start
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
    if (_game.score > _bestScore) _bestScore = _game.score;
    setState(() => _game = _game.copyWith(phase: _Phase.gameOver));
    _gameOverCtrl.forward(from: 0);
    _submitResult();
  }

  Future<void> _submitResult() async {
    final timePlayed = _gameStartTime != null
        ? DateTime.now().difference(_gameStartTime!).inSeconds
        : 0;
    final result = await GameService.submitResult(
      gameType:          'pattern_trail',
      score:             _game.score,
      timePlayedSeconds: timePlayed,
      completed:         false,
      levelReached:      _game.level,
      mistakes:          _game.mistakes,
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final playing =
            _game.phase != _Phase.idle && _game.phase != _Phase.gameOver;
        if (playing) await _submitResult();
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
          if (showStats)
            _LivesRow(lives: _game.lives)
          else
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
      case _Phase.levelUp:
        return _buildLevelUpScreen();
      case _Phase.gameOver:
        return FadeTransition(
            opacity: _gameOverFade, child: _buildGameOverScreen());
    }
  }

  // ── Idle screen ──────────────────────────────────────────────────────────

  Widget _buildIdleScreen() {
    final gs = _game.gridSize;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        children: [
          // Glow icon
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
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
          const SizedBox(height: 10),
          Text(
            'Watch the dots light up one by one.\nTap them back in the exact same order!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 18),

          // Preview grid
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder),
            ),
            child: Column(
              children: [
                _PreviewDotGrid(gridSize: gs),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LegendDot(color: _kAccent,  label: 'Sequence'),
                    const SizedBox(width: 14),
                    _LegendDot(color: _kCorrect, label: 'Correct'),
                    const SizedBox(width: 14),
                    _LegendDot(color: _kWrong,   label: 'Wrong'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Best score badge
          if (_bestScore > 0) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _kGold.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kGold.withOpacity(0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.emoji_events_rounded,
                    color: _kGold, size: 16),
                const SizedBox(width: 6),
                Text('Best: $_bestScore pts',
                    style: const TextStyle(
                        color: _kGold,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 20),
          ] else
            const SizedBox(height: 4),

          // Difficulty selector
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Difficulty',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 10),
          Row(
            children: PatternTrailDifficulty.values.map((d) {
              final active = _game.difficulty == d;
              final label  = d == PatternTrailDifficulty.easy   ? 'Easy'
                           : d == PatternTrailDifficulty.medium ? 'Medium'
                           : 'Hard';
              final hint   = d == PatternTrailDifficulty.easy   ? '3×3  slow'
                           : d == PatternTrailDifficulty.medium ? '4×4  normal'
                           : '4×4  fast';
              final col    = d == PatternTrailDifficulty.easy   ? _kCorrect
                           : d == PatternTrailDifficulty.medium ? _kGold
                           : _kWrong;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      right: d != PatternTrailDifficulty.hard ? 8 : 0),
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _game = _game.copyWith(difficulty: d)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: active ? col.withOpacity(0.16) : _kCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: active
                                ? col.withOpacity(0.55)
                                : _kBorder),
                      ),
                      child: Column(children: [
                        Text(label,
                            style: TextStyle(
                                color: active ? col : Colors.grey[500],
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(hint,
                            style: TextStyle(
                                color: active
                                    ? col.withOpacity(0.65)
                                    : Colors.grey[700],
                                fontSize: 10)),
                      ]),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 30),

          // Start button
          GestureDetector(
            onTap: _startGame,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF1A6DB5), _kAccent]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: _kAccent.withOpacity(0.38),
                      blurRadius: 24,
                      offset: const Offset(0, 10)),
                ],
              ),
              child: const Center(
                child: Text('Start',
                    style: TextStyle(
                        color: Colors.white,
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

  // ── Active game screen (showing + input phases) ───────────────────────────

  Widget _buildGameScreen() {
    final gs        = _game.gridSize;
    final isShowing = _game.phase == _Phase.showing;
    final progress  = _game.playerProgress;
    final seqLen    = _game.sequence.length;

    return Column(
      children: [
        const SizedBox(height: 16),

        // Phase label
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

        // Step progress indicators
        if (seqLen > 0)
          _SequenceProgressBar(
            length:   seqLen,
            done:     progress,
            isShowing: isShowing,
          ),

        const SizedBox(height: 16),

        // Dot grid
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

  // ── Level-up screen ───────────────────────────────────────────────────────

  Widget _buildLevelUpScreen() {
    // Points are already added to score; recover last-round value retroactively:
    // before increment: level was (_game.level - 1), seqLen was (_game.sequenceLength - 1)
    final prevPoints = (_game.level - 1) * (_game.sequenceLength - 1) * 10;

    return Center(
      child: ScaleTransition(
        scale: _levelUpScale,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                    colors: [Color(0xFFFFD166), Color(0xFFFF9A3C)]),
                boxShadow: [
                  BoxShadow(
                      color: _kGold.withOpacity(0.45),
                      blurRadius: 36,
                      spreadRadius: 4),
                ],
              ),
              child: const Icon(Icons.star_rounded,
                  color: Colors.white, size: 46),
            ),
            const SizedBox(height: 20),
            const Text('Level Up!',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5)),
            const SizedBox(height: 8),
            Text('Now on level ${_game.level}',
                style: const TextStyle(color: _kMuted, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Sequence grows to ${_game.sequenceLength} dots',
                style: const TextStyle(
                    color: _kAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('+$prevPoints pts',
                style: const TextStyle(
                    color: _kGold,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // ── Game over screen ──────────────────────────────────────────────────────

  Widget _buildGameOverScreen() {
    final isNewBest = _game.score > 0 && _game.score >= _bestScore;
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
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5)),
            if (isNewBest) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: _kGold.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kGold.withOpacity(0.40)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.emoji_events_rounded, color: _kGold, size: 14),
                  SizedBox(width: 5),
                  Text('New Best!',
                      style: TextStyle(
                          color: _kGold,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ],
            const SizedBox(height: 28),
            _StatRow(
                label: 'Final Score',
                value: '${_game.score} pts',
                valueColor: _kAccent),
            const SizedBox(height: 8),
            _StatRow(
                label: 'Level Reached',
                value: '${_game.level}',
                valueColor: _kGold),
            const SizedBox(height: 8),
            _StatRow(
                label: 'Longest Sequence',
                value: '${_game.sequenceLength} dots',
                valueColor: const Color(0xFF818CF8)),
            const SizedBox(height: 8),
            _StatRow(
                label: 'Mistakes',
                value: '${_game.mistakes}',
                valueColor: _kWrong),
            const SizedBox(height: 44),
            _PrimaryButton(label: 'Play Again', onTap: _startGame),
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
// Preview dot grid  (idle screen)
// ─────────────────────────────────────────────────────────────────────────────

class _PreviewDotGrid extends StatelessWidget {
  final int gridSize;
  const _PreviewDotGrid({required this.gridSize});

  @override
  Widget build(BuildContext context) {
    // Highlight a short sample sequence for illustration
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
                            color: Colors.white,
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
// Sequence progress bar  (small dots above the grid)
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
// Legend dot  (idle screen)
// ─────────────────────────────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  final Color  color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(color: _kMuted, fontSize: 10)),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared header widgets
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
              color: Colors.white, size: 16),
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
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ]),
      );
}

class _LivesRow extends StatelessWidget {
  final int lives;
  const _LivesRow({required this.lives});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          3,
          (i) => Padding(
            padding: const EdgeInsets.only(left: 3),
            child: Icon(
              i < lives
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: i < lives ? _kWrong : Colors.grey[700],
              size: 18,
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared stat / button widgets
// ─────────────────────────────────────────────────────────────────────────────

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
            gradient: const LinearGradient(
                colors: [Color(0xFF1A6DB5), _kAccent]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: _kAccent.withOpacity(0.38),
                  blurRadius: 22,
                  offset: const Offset(0, 9)),
            ],
          ),
          child: Center(
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white,
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
