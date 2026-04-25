import 'dart:async';

import 'package:capstone_front_end/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/daily_score_provider.dart';
import '../../../../core/widgets/score_gain_toast.dart';
import '../../services/game_progress_service.dart';
import '../../services/game_service.dart';
import '../models/color_match_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design constants — Deep Focus light theme
// ─────────────────────────────────────────────────────────────────────────────

const _kBg     = AppColors.surface;
const _kCard   = AppColors.surfaceContainerLowest;
const _kBorder = AppColors.outlineVariant;
const _kAccent = AppColors.secondary;
const _kGold   = AppColors.primaryFixed;
const _kWrong  = AppColors.error;
const _kMuted  = AppColors.onSurfaceVariant;

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class ColorMatchPage extends StatefulWidget {
  final int startLevel;
  const ColorMatchPage({super.key, this.startLevel = 1});

  @override
  State<ColorMatchPage> createState() => _ColorMatchPageState();
}

class _ColorMatchPageState extends State<ColorMatchPage>
    with TickerProviderStateMixin {

  // ── Game state ──────────────────────────────────────────────────────────────
  late ColorMatchState _game;
  DateTime? _gameStartTime;
  Timer? _gameTimer;
  bool _feedbackShowing = false;
  int? _tappedIndex;
  bool _lastTapCorrect = false;
  bool _resultSubmitted = false;

  static int _bestScore = 0;

  // ── Animation controllers ───────────────────────────────────────────────────
  late AnimationController _cdCtrl;
  late AnimationController _levelCompleteCtrl;
  late AnimationController _wordCtrl;
  late Animation<double>   _cdScale;
  late Animation<double>   _levelCompleteFade;

  @override
  void initState() {
    super.initState();
    _game = ColorMatchState.initial(widget.startLevel);

    _cdCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));
    _levelCompleteCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 450));
    _wordCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300));

    _cdScale = Tween<double>(begin: 0.75, end: 1.0).animate(
        CurvedAnimation(parent: _cdCtrl, curve: Curves.elasticOut));
    _levelCompleteFade = CurvedAnimation(
        parent: _levelCompleteCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _cdCtrl.dispose();
    _levelCompleteCtrl.dispose();
    _wordCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Game flow
  // ─────────────────────────────────────────────────────────────────────────

  void _startGame() {
    HapticFeedback.mediumImpact();
    _gameTimer?.cancel();
    _resultSubmitted = false;
    setState(() {
      _game = ColorMatchState.initial(widget.startLevel)
          .copyWith(phase: ColorMatchPhase.countdown, countdown: 3);
      _feedbackShowing = false;
      _tappedIndex = null;
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
    _gameTimer = Timer.periodic(const Duration(seconds: 1), _onTimerTick);
    _nextRound();
  }

  void _onTimerTick(Timer t) {
    if (!mounted) { t.cancel(); return; }
    final remaining = _game.timeLeft - 1;
    if (remaining <= 0) {
      t.cancel();
      setState(() => _game = _game.copyWith(timeLeft: 0));
      _endGame();
    } else {
      setState(() => _game = _game.copyWith(timeLeft: remaining));
    }
  }

  void _nextRound() {
    if (!mounted) return;
    setState(() {
      _game = _game.copyWith(
        phase: ColorMatchPhase.playing,
        round: generateRound(_game.level),
      );
      _feedbackShowing = false;
      _tappedIndex = null;
    });
  }

  void _onColorTap(int index) {
    if (_game.phase != ColorMatchPhase.playing || _feedbackShowing) return;
    if (_game.round == null) return;

    HapticFeedback.lightImpact();
    final round   = _game.round!;
    final tapped  = round.choices[index];
    final correct = tapped.name == round.inkColor.name;

    setState(() {
      _tappedIndex     = index;
      _feedbackShowing = true;
      _lastTapCorrect  = correct;
    });

    if (correct) {
      final newStreak = _game.streak + 1;
      final points    = 100 + (newStreak - 1) * 15;
      setState(() {
        _game = _game.copyWith(
          score:      _game.score + points,
          streak:     newStreak,
          bestStreak: newStreak > _game.bestStreak ? newStreak : _game.bestStreak,
          correct:    _game.correct + 1,
        );
      });
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) _nextRound();
      });
    } else {
      HapticFeedback.heavyImpact();
      setState(() => _game = _game.copyWith(
        streak:   0,
        mistakes: _game.mistakes + 1,
      ));
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _nextRound();
      });
    }
  }

  void _endGame() {
    _gameTimer?.cancel();
    if (_game.score > _bestScore) _bestScore = _game.score;
    setState(() => _game = _game.copyWith(phase: ColorMatchPhase.levelComplete));
    _levelCompleteCtrl.forward(from: 0);
    _doLevelComplete();
  }

  Future<void> _doLevelComplete() async {
    if (!_resultSubmitted) {
      _resultSubmitted = true;
      final nextLevel = widget.startLevel + 1;
      await GameProgressService.unlockUpToLevel('color_match', nextLevel);
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
    // Higher base score so the backend returns meaningful focus points.
    // Formula: level bonus + accuracy bonus, scaled to 100-1000 range.
    final int normalizedScore =
        (widget.startLevel * 80 + accuracyRate * 500).round().clamp(100, 1000);
    // Local fallback in case the backend is unreachable or returns 0.
    final double localFocusPoints =
        (widget.startLevel * 0.3 + accuracyRate * 2.5).clamp(1.0, 8.0);
    final result = await GameService.submitResult(
      gameType:          'color_match',
      score:             normalizedScore,
      timePlayedSeconds: timePlayed,
      completed:         true,
      levelReached:      widget.startLevel + 1,
      mistakes:          _game.mistakes,
    );
    if (!mounted) return;
    final double pointsToAdd = (result != null && result.focusScoreGained > 0)
        ? result.focusScoreGained
        : localFocusPoints;
    context.read<DailyScoreProvider>().addPoints(pointsToAdd);
    ScoreGainToast.show(context, pointsToAdd, source: 'Color Match');
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
        if (_game.phase == ColorMatchPhase.playing && !_resultSubmitted) {
          _gameTimer?.cancel();
          _resultSubmitted = true;
          await _submitResult();
        }
        if (mounted) Navigator.pop(context);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: _kBg,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                if (_game.phase == ColorMatchPhase.playing) _buildTimerBar(),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final isPlaying = _game.phase == ColorMatchPhase.playing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          _BackButton(onTap: () => Navigator.maybePop(context)),
          const Spacer(),
          if (isPlaying) ...[
            _ScoreChip(score: _game.score, streak: _game.streak),
            const SizedBox(width: 10),
          ],
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  // ── Timer bar ───────────────────────────────────────────────────────────────

  Widget _buildTimerBar() {
    final fraction = (_game.timeLeft / _game.totalTimer).clamp(0.0, 1.0);
    final barColor = fraction > 0.5 ? _kAccent
        : fraction > 0.25 ? _kGold
        : _kWrong;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_game.timeLeft}s',
                  style: TextStyle(color: barColor, fontSize: 12,
                      fontWeight: FontWeight.w600)),
              Text('${_game.totalTimer}s',
                  style: const TextStyle(color: _kMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: fraction, end: fraction),
              duration: const Duration(milliseconds: 800),
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 5,
                backgroundColor: Colors.white.withOpacity(0.07),
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Body router ─────────────────────────────────────────────────────────────

  Widget _buildBody() {
    switch (_game.phase) {
      case ColorMatchPhase.idle:
        return _buildIdleScreen();
      case ColorMatchPhase.countdown:
        return _buildCountdownScreen();
      case ColorMatchPhase.playing:
        return _buildPlayScreen();
      case ColorMatchPhase.levelComplete:
        return FadeTransition(
            opacity: _levelCompleteFade, child: _buildLevelCompleteScreen());
    }
  }

  // ── Idle screen ─────────────────────────────────────────────────────────────

  Widget _buildIdleScreen() {
    final timer = ColorMatchState.timerForLevel(widget.startLevel);
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
            child: const Icon(Icons.palette_outlined, color: _kAccent, size: 42),
          ),
          const SizedBox(height: 18),
          const Text('Color Match',
              style: TextStyle(color: AppColors.onSurface, fontSize: 28,
                  fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 10),
          Text(
            'Tap the button matching the INK color,\nnot what the word says.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 18),

          // Example: "RED" in blue ink → tap BLUE
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('RED',
                    style: TextStyle(
                      color: Color(0xFF3B82F6),
                      fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 5,
                      shadows: [Shadow(color: Color(0x803B82F6), blurRadius: 12)],
                    )),
                const SizedBox(width: 18),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('→ tap',
                        style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('BLUE',
                          style: TextStyle(color: Colors.white, fontSize: 11,
                              fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

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
                Text('Best: $_bestScore pts',
                    style: const TextStyle(color: _kGold, fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 20),
          ] else
            const SizedBox(height: 4),

          // Level info chips
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _InfoChip(icon: Icons.bar_chart_rounded,
                  label: 'Level ${widget.startLevel}'),
              const SizedBox(width: 10),
              _InfoChip(icon: Icons.timer_rounded, label: '${timer}s'),
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

  // ── Countdown screen ─────────────────────────────────────────────────────────

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
          const Text('Get ready...', style: TextStyle(color: _kMuted, fontSize: 16)),
        ],
      ),
    );
  }

  // ── Play screen ──────────────────────────────────────────────────────────────

  Widget _buildPlayScreen() {
    if (_game.round == null) return const SizedBox.shrink();
    final round = _game.round!;

    return Column(
      children: [
        const SizedBox(height: 16),
        Text(
          'Tap the INK color',
          style: TextStyle(color: _kMuted, fontSize: 13,
              fontWeight: FontWeight.w500, letterSpacing: 0.3),
        ),
        Expanded(
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              transitionBuilder: (child, anim) {
                final scale = Tween<double>(begin: 0.7, end: 1.0).animate(
                    CurvedAnimation(parent: anim, curve: Curves.elasticOut));
                return ScaleTransition(
                    scale: scale,
                    child: FadeTransition(opacity: anim, child: child));
              },
              child: Text(
                round.word,
                key: ValueKey('${round.word}_${round.inkColor.name}'),
                style: TextStyle(
                  color: round.inkColor.color,
                  fontSize: 72,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                  shadows: [
                    Shadow(
                        color: round.inkColor.color.withOpacity(0.55),
                        blurRadius: 28),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            children: [
              _buildButtonRow(0, 1, round),
              const SizedBox(height: 12),
              _buildButtonRow(2, 3, round),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildButtonRow(int a, int b, ColorMatchRound round) => Row(
        children: [
          _colorButton(a, round),
          const SizedBox(width: 12),
          _colorButton(b, round),
        ],
      );

  Widget _colorButton(int index, ColorMatchRound round) {
    final entry          = round.choices[index];
    final isTapped       = _feedbackShowing && _tappedIndex == index;
    final isCorrectEntry = entry.name == round.inkColor.name;

    Color bgColor      = AppColors.surfaceContainerLow;
    Color borderColor  = AppColors.outlineVariant;
    Color labelColor   = AppColors.onSurface;
    double borderWidth = 1.5;

    if (_feedbackShowing) {
      if (isTapped && _lastTapCorrect) {
        bgColor     = _kAccent.withOpacity(0.18);
        borderColor = _kAccent;
        labelColor  = _kAccent;
        borderWidth = 2.5;
      } else if (isTapped && !_lastTapCorrect) {
        bgColor     = _kWrong.withOpacity(0.18);
        borderColor = _kWrong;
        labelColor  = _kWrong;
        borderWidth = 2.5;
      } else if (!_lastTapCorrect && isCorrectEntry) {
        bgColor     = _kAccent.withOpacity(0.12);
        borderColor = _kAccent.withOpacity(0.70);
        labelColor  = _kAccent;
        borderWidth = 2.5;
      }
    }

    return Expanded(
      child: GestureDetector(
        onTap: () => _onColorTap(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 70,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: Center(
            child: Text(
              entry.name,
              style: TextStyle(
                color: labelColor,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Level complete screen ────────────────────────────────────────────────────

  Widget _buildLevelCompleteScreen() {
    final nextLevel = widget.startLevel + 1;
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
            const SizedBox(height: 32),
            _StatRow(label: 'Score',
                value: '${_game.score} pts', valueColor: _kAccent),
            const SizedBox(height: 8),
            _StatRow(label: 'Best Streak',
                value: '×${_game.bestStreak}', valueColor: _kGold),
            const SizedBox(height: 8),
            _StatRow(label: 'Accuracy',
                value: '${_game.accuracy}%',
                valueColor: const Color(0xFF818CF8)),
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
// Private page-level widgets
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
                color: _kAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('×$streak',
                  style: const TextStyle(color: _kAccent,
                      fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
      );
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                  fontSize: 13, fontWeight: FontWeight.w600)),
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
              style: TextStyle(color: valueColor,
                  fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      );
}
