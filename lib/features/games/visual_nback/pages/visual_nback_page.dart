import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../services/game_service.dart';

// Accent color for N-Back game elements (grid highlight, stats)
const _kAccent = Color(0xFF7B6FFF);

class VisualNBackPage extends StatefulWidget {
  final void Function(int score, int timeSeconds, bool completed, int levelReached, int mistakes)? onScoreSubmitted;

  const VisualNBackPage({super.key, this.onScoreSubmitted});

  @override
  State<VisualNBackPage> createState() => _VisualNBackPageState();
}

class _VisualNBackPageState extends State<VisualNBackPage> {
  static const int _totalTrials = 30;
  static const int _nBack       = 2;

  List<int> _sequence = [];
  int  _currentTrial   = 0;
  int  _highlightedCell = -1;
  int  _score           = 0;
  int  _hitCount        = 0;
  int  _falseAlarmCount = 0;
  bool _responseGiven   = false;
  bool _gameOver        = false;
  bool _submitting      = false;
  Color? _gridBorderColor;

  Timer? _highlightTimer;
  Timer? _trialTimer;
  Timer? _feedbackTimer;

  @override
  void initState() {
    super.initState();
    _generateSequence();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startNextTrial());
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _trialTimer?.cancel();
    _feedbackTimer?.cancel();
    super.dispose();
  }

  void _generateSequence() {
    final seed = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;
    final rng  = Random(seed);
    _sequence  = List.generate(_totalTrials, (_) => -1);
    _sequence[0] = rng.nextInt(9);
    _sequence[1] = rng.nextInt(9);
    for (int i = _nBack; i < _totalTrials; i++) {
      if (rng.nextDouble() < 0.3) {
        _sequence[i] = _sequence[i - _nBack];
      } else {
        int pos;
        do { pos = rng.nextInt(9); } while (pos == _sequence[i - _nBack]);
        _sequence[i] = pos;
      }
    }
  }

  bool get _isMatch =>
      _currentTrial >= _nBack &&
      _sequence[_currentTrial] == _sequence[_currentTrial - _nBack];

  void _startNextTrial() {
    if (!mounted) return;
    if (_currentTrial >= _totalTrials) { _endGame(); return; }
    setState(() {
      _highlightedCell = _sequence[_currentTrial];
      _responseGiven   = false;
      _gridBorderColor = null;
    });
    _highlightTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _highlightedCell = -1);
    });
    _trialTimer = Timer(const Duration(milliseconds: 2000), () {
      if (_currentTrial >= _nBack && !_responseGiven) {
        _processResponse(false, fromTimer: true);
      }
      _currentTrial++;
      _startNextTrial();
    });
  }

  void _processResponse(bool respondedMatch, {bool fromTimer = false}) {
    if (_currentTrial < _nBack) return;
    if (_responseGiven && !fromTimer) return;
    _responseGiven = true;
    final correct = _isMatch;
    int delta;
    Color feedbackColor;
    if (respondedMatch && correct) {
      delta = 15; _hitCount++;
      feedbackColor = AppColors.secondary;
    } else if (!respondedMatch && !correct) {
      delta = 5;
      feedbackColor = AppColors.secondary;
    } else if (!respondedMatch && correct) {
      delta = -10;
      feedbackColor = AppColors.error;
    } else {
      delta = -15; _falseAlarmCount++;
      feedbackColor = AppColors.error;
    }
    _score = max(0, _score + delta);
    if (!fromTimer) {
      _feedbackTimer?.cancel();
      setState(() => _gridBorderColor = feedbackColor);
      _feedbackTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _gridBorderColor = null);
      });
    }
  }

  void _endGame() => setState(() => _gameOver = true);

  int get _totalScoredTrials => _totalTrials - _nBack;

  double get _accuracy {
    final correctRejections = _totalScoredTrials - _hitCount - _falseAlarmCount;
    return (_hitCount + max(0, correctRejections)) / _totalScoredTrials * 100;
  }

  String get _ratingLabel {
    final a = _accuracy;
    if (a >= 85) return 'Sharp Memory';
    if (a >= 70) return 'Good';
    if (a >= 55) return 'Average';
    return 'Keep Training';
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    // Normalized score 0-1000: precision = hits / (hits + false alarms)
    final int total = _hitCount + _falseAlarmCount;
    final double precision = total > 0 ? _hitCount / total : 0.5;
    final int normalizedScore = (precision * 1000).round().clamp(0, 1000);
    await GameService.submitResult(
      gameType: 'visual_nback', score: normalizedScore,
      timePlayedSeconds: 60, completed: true,
      levelReached: _hitCount, mistakes: _falseAlarmCount,
    );
    widget.onScoreSubmitted?.call(_score, 60, true, _hitCount, _falseAlarmCount);
    if (mounted) Navigator.pop(context);
  }

  void _playAgain() {
    _highlightTimer?.cancel();
    _trialTimer?.cancel();
    _feedbackTimer?.cancel();
    setState(() {
      _score = 0; _hitCount = 0; _falseAlarmCount = 0;
      _currentTrial = 0; _highlightedCell = -1;
      _responseGiven = false; _gameOver = false;
      _submitting = false; _gridBorderColor = null;
    });
    _generateSequence();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startNextTrial());
  }

  @override
  Widget build(BuildContext context) {
    if (_gameOver) return _buildGameOver();

    final showButtons = _currentTrial >= _nBack;
    final trial       = _currentTrial + 1;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(trial),
          Expanded(child: Center(child: _buildGrid())),
          if (!showButtons)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text('Watch the pattern…',
                  style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14)),
            )
          else
            _buildButtons(),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _buildTopBar(int trial) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant.withOpacity(0.5))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.onSurfaceVariant, size: 14),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Visual N-Back',
                style: TextStyle(color: AppColors.onSurface,
                    fontSize: 15, fontWeight: FontWeight.bold)),
            Text('Trial $trial / $_totalTrials',
                style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _kAccent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kAccent.withOpacity(0.25)),
          ),
          child: Text('$_score pts',
              style: const TextStyle(
                  color: _kAccent, fontSize: 14, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text('N = 2',
              style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11)),
        ),
      ]),
    );
  }

  Widget _buildGrid() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: _gridBorderColor != null
            ? Border.all(color: _gridBorderColor!, width: 3)
            : Border.all(color: Colors.transparent, width: 3),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (row) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (col) {
              final idx         = row * 3 + col;
              final highlighted = idx == _highlightedCell;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: highlighted
                        ? _kAccent
                        : AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: highlighted ? _kAccent : AppColors.outlineVariant,
                      width: highlighted ? 2 : 1,
                    ),
                    boxShadow: highlighted
                        ? [BoxShadow(
                            color: _kAccent.withOpacity(0.35),
                            blurRadius: 16)]
                        : [BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                ),
              );
            }),
          ),
        )),
      ),
    );
  }

  Widget _buildButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        height: 60,
        child: Row(children: [
          Expanded(child: _ResponseButton(
            label: 'MATCH', icon: Icons.check_rounded,
            accentColor: AppColors.secondary,
            onTap: () => _processResponse(true),
          )),
          const SizedBox(width: 12),
          Expanded(child: _ResponseButton(
            label: 'NO MATCH', icon: Icons.close_rounded,
            accentColor: AppColors.onSurfaceVariant,
            onTap: () => _processResponse(false),
          )),
        ]),
      ),
    );
  }

  Widget _buildGameOver() {
    final accuracy = _accuracy;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(children: [
          // Header
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              border: Border(bottom: BorderSide(color: AppColors.outlineVariant.withOpacity(0.5))),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Icon(Icons.close_rounded,
                      color: AppColors.onSurfaceVariant, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              const Text('N-Back Results',
                  style: TextStyle(color: AppColors.onSurface,
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
          ),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Score card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Column(children: [
                  Text('$_score',
                      style: const TextStyle(color: AppColors.onSurface,
                          fontSize: 56, fontWeight: FontWeight.w900)),
                  Text('points', style: TextStyle(
                      color: AppColors.onSurfaceVariant, fontSize: 13)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _kAccent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _kAccent.withOpacity(0.25)),
                    ),
                    child: Text(_ratingLabel,
                        style: const TextStyle(color: _kAccent,
                            fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              // Stats
              _StatsCard(children: [
                _StatRow('Hits', '$_hitCount'),
                _StatRow('False alarms', '$_falseAlarmCount'),
                _StatRow('Accuracy', '${accuracy.toStringAsFixed(0)}%'),
              ]),
              const SizedBox(height: 16),
              // Insight
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.science_outlined, color: AppColors.secondary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    'N-Back performance correlates with fluid intelligence — the ability to reason through new problems.',
                    style: TextStyle(color: AppColors.onSurfaceVariant,
                        fontSize: 12, height: 1.5),
                  )),
                ]),
              ),
              const SizedBox(height: 28),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: _playAgain,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.onSurface,
                    side: const BorderSide(color: AppColors.outlineVariant),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Done',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                )),
              ]),
            ]),
          )),
        ]),
      ),
    );
  }
}

// ── Shared sub-widgets ─────────────────────────────────────────────────────────

class _ResponseButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _ResponseButton({
    required this.label, required this.icon,
    required this.accentColor, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accentColor.withOpacity(0.4)),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: accentColor, size: 20),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(
              color: accentColor, fontSize: 13, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final List<Widget> children;
  const _StatsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(children: children),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _StatRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Text(label, style: const TextStyle(
            color: AppColors.onSurfaceVariant, fontSize: 14)),
        const Spacer(),
        Text(value, style: TextStyle(
            color: valueColor ?? AppColors.onSurface,
            fontSize: 14, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
