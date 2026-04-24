import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../services/game_service.dart';

const _kAccent = Color(0xFF06B6D4);

enum _ArrowDir { left, right }

class _Trial {
  final _ArrowDir center;
  final _ArrowDir flanker;
  bool get isCongruent => center == flanker;

  const _Trial(this.center, this.flanker);
}

class FlankerTaskPage extends StatefulWidget {
  final void Function(int score, int timeSeconds, bool completed, int levelReached, int mistakes)? onScoreSubmitted;

  const FlankerTaskPage({super.key, this.onScoreSubmitted});

  @override
  State<FlankerTaskPage> createState() => _FlankerTaskPageState();
}

class _FlankerTaskPageState extends State<FlankerTaskPage> {
  static const int _totalRounds = 30;
  static const int _maxSeconds = 90;
  static const int _trialTimeoutMs = 2000;

  List<_Trial> _trials = [];
  int _round = 0;
  int _score = 0;
  int _secondsLeft = _maxSeconds;
  int _totalCorrect = 0;
  int _totalWrong = 0;
  bool _gameOver = false;
  bool _submitting = false;
  bool _showStimulus = true;
  int? _flashButton; // 0 = left, 1 = right
  bool _lastCorrect = false;
  int _roundStartMs = 0;

  int _congruentTotal = 0;
  int _incongruentTotal = 0;
  int _congruentTotalRt = 0;
  int _incongruentTotalRt = 0;

  Timer? _countdownTimer;
  Timer? _trialTimer;
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    _generateTrials();
    _startGame();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _trialTimer?.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }

  void _generateTrials() {
    final seed = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;
    final rng = Random(seed);
    final raw = <_Trial>[];
    int consecutiveSame = 0;
    bool lastCongruent = rng.nextBool();

    for (int i = 0; i < _totalRounds; i++) {
      bool congruent;
      if (consecutiveSame >= 4) {
        congruent = !lastCongruent;
      } else {
        congruent = rng.nextDouble() < 0.6;
      }
      consecutiveSame = (congruent == lastCongruent) ? consecutiveSame + 1 : 1;
      lastCongruent = congruent;

      final center = rng.nextBool() ? _ArrowDir.left : _ArrowDir.right;
      final flanker = congruent ? center : (center == _ArrowDir.left ? _ArrowDir.right : _ArrowDir.left);
      raw.add(_Trial(center, flanker));
    }
    _trials = raw;
  }

  void _startGame() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        _endGame(timedOut: true);
      }
    });
    _startRound();
  }

  void _startRound() {
    if (_round >= _totalRounds) {
      _endGame(timedOut: false);
      return;
    }
    setState(() {
      _showStimulus = true;
      _flashButton = null;
      _roundStartMs = DateTime.now().millisecondsSinceEpoch;
    });

    _trialTimer = Timer(const Duration(milliseconds: _trialTimeoutMs), () {
      if (_showStimulus && mounted) {
        setState(() => _score = max(0, _score - 3));
        _round++;
        _startRound();
      }
    });
  }

  void _onResponse(_ArrowDir chosen) {
    if (!_showStimulus || _gameOver) return;
    _trialTimer?.cancel();

    final trial = _trials[_round];
    final rt = DateTime.now().millisecondsSinceEpoch - _roundStartMs;
    final correct = chosen == trial.center;

    if (trial.isCongruent) {
      _congruentTotal++;
      if (correct) _congruentTotalRt += rt;
    } else {
      _incongruentTotal++;
      if (correct) _incongruentTotalRt += rt;
    }

    int delta;
    if (correct) {
      delta = 10;
      if (rt <= 400) { delta += 6; }
      else if (rt <= 700) { delta += 3; }
      _totalCorrect++;
      HapticFeedback.lightImpact();
    } else {
      delta = -5;
      _totalWrong++;
      HapticFeedback.heavyImpact();
    }
    _score = max(0, _score + delta);
    _lastCorrect = correct;

    setState(() {
      _showStimulus = false;
      _flashButton = chosen == _ArrowDir.left ? 0 : 1;
    });

    _flashTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _round++;
      _startRound();
    });
  }

  void _endGame({required bool timedOut}) {
    _trialTimer?.cancel();
    _countdownTimer?.cancel();
    setState(() {
      _showStimulus = false;
      _gameOver = true;
    });
  }

  int get _secondsElapsed => _maxSeconds - _secondsLeft;

  int get _avgCongruentRt =>
      (_congruentTotal > 0) ? (_congruentTotalRt ~/ _congruentTotal) : 0;

  int get _avgIncongruentRt =>
      (_incongruentTotal > 0) ? (_incongruentTotalRt ~/ _incongruentTotal) : 0;

  int get _flankerEffect => _avgIncongruentRt - _avgCongruentRt;

  int get _avgRt {
    final total = _congruentTotalRt + _incongruentTotalRt;
    final count = _congruentTotal + _incongruentTotal;
    return count > 0 ? (total ~/ count) : 0;
  }

  String get _flankerRating {
    final fe = _flankerEffect;
    if (fe < 100) return 'Excellent Control';
    if (fe < 200) return 'Good';
    if (fe < 350) return 'Average';
    return 'Needs Work';
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final elapsed = _secondsElapsed;
    final completed = _round >= _totalRounds;
    // Normalized score 0-1000: accuracy × 900 + completion bonus 100
    final int total = _totalCorrect + _totalWrong;
    final double accuracyRate = total > 0 ? _totalCorrect / total : 0.5;
    final int completionBonus = completed ? 100 : 0;
    final int normalizedScore = (accuracyRate * 900 + completionBonus).round().clamp(0, 1000);
    await GameService.submitResult(
      gameType: 'flanker_task',
      score: normalizedScore,
      timePlayedSeconds: elapsed,
      completed: completed,
      levelReached: _totalCorrect,
      mistakes: _totalWrong,
    );
    widget.onScoreSubmitted?.call(_score, elapsed, completed, _totalCorrect, _totalWrong);
    if (mounted) Navigator.pop(context);
  }

  void _playAgain() {
    _countdownTimer?.cancel();
    _trialTimer?.cancel();
    _flashTimer?.cancel();
    setState(() {
      _round = 0;
      _score = 0;
      _secondsLeft = _maxSeconds;
      _totalCorrect = 0;
      _totalWrong = 0;
      _gameOver = false;
      _submitting = false;
      _showStimulus = true;
      _flashButton = null;
      _congruentTotal = 0;
      _incongruentTotal = 0;
      _congruentTotalRt = 0;
      _incongruentTotalRt = 0;
    });
    _generateTrials();
    _startGame();
  }

  @override
  Widget build(BuildContext context) {
    if (_gameOver) return _buildGameOver();

    final trial = _round < _totalRounds ? _trials[_round] : null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(children: [
        _buildHeader(),
        Expanded(child: Center(
          child: _showStimulus && trial != null
              ? _buildArrowRow(trial)
              : const SizedBox.shrink(),
        )),
        _buildButtons(),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant, width: 1)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Icon(Icons.close_rounded, color: AppColors.onSurfaceVariant, size: 18),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Round ${min(_round + 1, _totalRounds)} / $_totalRounds',
          style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14),
        ),
        const Spacer(),
        Text(
          '$_score pts',
          style: TextStyle(color: AppColors.onSurface, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 12),
        Text(
          '${_secondsLeft}s',
          style: TextStyle(
            color: _secondsLeft <= 10 ? const Color(0xFFEF4444) : AppColors.onSurfaceVariant,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ]),
    );
  }

  Widget _buildArrowRow(_Trial trial) {
    final widgets = <Widget>[];
    for (int i = 0; i < 5; i++) {
      final isCenterArrow = i == 2;
      final dir = isCenterArrow ? trial.center : trial.flanker;
      final icon = dir == _ArrowDir.left ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded;
      widgets.add(Icon(
        icon,
        color: isCenterArrow ? _kAccent : AppColors.onSurfaceVariant,
        size: isCenterArrow ? 52 : 40,
      ));
      if (i < 4) widgets.add(const SizedBox(width: 4));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: widgets);
  }

  Widget _buildButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        height: 90,
        child: Row(children: [
          Expanded(child: _ArrowButton(
            label: 'LEFT',
            icon: Icons.arrow_back_rounded,
            flash: _flashButton == 0,
            correct: _lastCorrect,
            onTap: () => _onResponse(_ArrowDir.left),
          )),
          const SizedBox(width: 12),
          Expanded(child: _ArrowButton(
            label: 'RIGHT',
            icon: Icons.arrow_forward_rounded,
            flash: _flashButton == 1,
            correct: _lastCorrect,
            onTap: () => _onResponse(_ArrowDir.right),
          )),
        ]),
      ),
    );
  }

  Widget _buildGameOver() {
    final fe = _flankerEffect;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Icon(Icons.close_rounded, color: AppColors.onSurfaceVariant, size: 18),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.outlineVariant),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(children: [
                  Text(
                    'Flanker Results',
                    style: TextStyle(color: AppColors.onSurface, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$_score',
                    style: TextStyle(color: _kAccent, fontSize: 64, fontWeight: FontWeight.w900),
                  ),
                  Text('pts', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14)),
                ]),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Column(children: [
                  _StatRow('Correct', '$_totalCorrect / $_totalRounds'),
                  _StatRow('Errors', '$_totalWrong'),
                  _StatRow('Avg response time', '${_avgRt}ms'),
                ]),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _kAccent.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kAccent.withValues(alpha: 0.25)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    'Flanker Effect: ${fe}ms — lower is better',
                    style: const TextStyle(color: _kAccent, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _flankerRating,
                    style: TextStyle(color: AppColors.onSurface, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Text(
                'The Flanker Effect measures how much surrounding distractors slow you down. Elite performers show near-zero interference.',
                style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 32),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: _playAgain,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.onSurface,
                    side: BorderSide(color: AppColors.outlineVariant),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Play Again'),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                )),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool flash;
  final bool correct;
  final VoidCallback onTap;

  const _ArrowButton({
    required this.label,
    required this.icon,
    required this.flash,
    required this.correct,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final flashColor = flash
        ? (correct ? const Color(0xFF10B981) : const Color(0xFFEF4444))
        : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 90,
        decoration: BoxDecoration(
          color: flash ? flashColor.withValues(alpha: 0.12) : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: flash ? flashColor : _kAccent.withValues(alpha: 0.4),
            width: flash ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: flash ? flashColor : _kAccent, size: 32),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: flash ? flashColor : AppColors.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ]),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Text(label, style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(color: AppColors.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ]),
    );
  }
}
