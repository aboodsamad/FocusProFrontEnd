import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../services/game_service.dart';

class VisualNBackPage extends StatefulWidget {
  final void Function(int score, int timeSeconds, bool completed, int levelReached, int mistakes)? onScoreSubmitted;

  const VisualNBackPage({super.key, this.onScoreSubmitted});

  @override
  State<VisualNBackPage> createState() => _VisualNBackPageState();
}

class _VisualNBackPageState extends State<VisualNBackPage> {
  static const int _totalTrials = 30;
  static const int _nBack = 2;

  List<int> _sequence = [];
  int _currentTrial = 0;
  int _highlightedCell = -1;
  int _score = 0;
  int _hitCount = 0;
  int _falseAlarmCount = 0;
  bool _responseGiven = false;
  bool _gameOver = false;
  bool _submitting = false;
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
    final rng = Random(seed);
    _sequence = List.generate(_totalTrials, (_) => -1);

    // First 2 trials: any position
    _sequence[0] = rng.nextInt(9);
    _sequence[1] = rng.nextInt(9);

    // Trials 2-29: ~30% matches
    for (int i = _nBack; i < _totalTrials; i++) {
      if (rng.nextDouble() < 0.3) {
        // Match: same position as 2 back
        _sequence[i] = _sequence[i - _nBack];
      } else {
        // Non-match: different position
        int pos;
        do {
          pos = rng.nextInt(9);
        } while (pos == _sequence[i - _nBack]);
        _sequence[i] = pos;
      }
    }
  }

  bool get _isMatch => _currentTrial >= _nBack && _sequence[_currentTrial] == _sequence[_currentTrial - _nBack];

  void _startNextTrial() {
    if (!mounted) return;
    if (_currentTrial >= _totalTrials) {
      _endGame();
      return;
    }

    setState(() {
      _highlightedCell = _sequence[_currentTrial];
      _responseGiven = false;
      _gridBorderColor = null;
    });

    _highlightTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _highlightedCell = -1);
    });

    _trialTimer = Timer(const Duration(milliseconds: 2000), () {
      // If trial requires response and none given, treat as NO MATCH
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
    int delta = 0;
    Color feedbackColor;

    if (respondedMatch && correct) {
      // Hit
      delta = 15;
      _hitCount++;
      feedbackColor = const Color(0xFF10B981);
    } else if (!respondedMatch && !correct) {
      // Correct rejection
      delta = 5;
      feedbackColor = const Color(0xFF10B981);
    } else if (!respondedMatch && correct) {
      // Miss
      delta = -10;
      feedbackColor = const Color(0xFFEF4444);
    } else {
      // False alarm
      delta = -15;
      _falseAlarmCount++;
      feedbackColor = const Color(0xFFEF4444);
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

  void _endGame() {
    setState(() => _gameOver = true);
  }

  int get _totalScoredTrials => _totalTrials - _nBack; // 28

  String get _ratingLabel {
    final accuracy = _accuracy;
    if (accuracy >= 85) return 'Sharp Memory';
    if (accuracy >= 70) return 'Good';
    if (accuracy >= 55) return 'Average';
    return 'Keep Training';
  }

  double get _accuracy {
    final correctRejections = _totalScoredTrials - _hitCount - _falseAlarmCount;
    return (_hitCount + max(0, correctRejections)) / _totalScoredTrials * 100;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    await GameService.submitResult(
      gameType: 'visual_nback',
      score: _score,
      timePlayedSeconds: 60,
      completed: true,
      levelReached: _hitCount,
      mistakes: _falseAlarmCount,
    );
    widget.onScoreSubmitted?.call(_score, 60, true, _hitCount, _falseAlarmCount);
    if (mounted) Navigator.pop(context);
  }

  void _playAgain() {
    _highlightTimer?.cancel();
    _trialTimer?.cancel();
    _feedbackTimer?.cancel();
    setState(() {
      _score = 0;
      _hitCount = 0;
      _falseAlarmCount = 0;
      _currentTrial = 0;
      _highlightedCell = -1;
      _responseGiven = false;
      _gameOver = false;
      _submitting = false;
      _gridBorderColor = null;
    });
    _generateSequence();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startNextTrial());
  }

  @override
  Widget build(BuildContext context) {
    if (_gameOver) return _buildGameOver();

    final showButtons = _currentTrial >= _nBack;
    final trial = _currentTrial + 1;

    return Scaffold(
      backgroundColor: const Color(0xFF080D1A),
      body: SafeArea(
        child: Column(
          children: [
            _buildStatusBar(trial),
            const SizedBox(height: 24),
            _buildGrid(),
            const SizedBox(height: 24),
            if (!showButtons)
              Text('Watch the pattern...',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14))
            else
              _buildButtons(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar(int trial) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.close_rounded, color: Colors.white54, size: 22),
        ),
        const SizedBox(width: 12),
        Text('Trial $trial / $_totalTrials',
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const Spacer(),
        Text('$_score pts',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text('N = 2',
              style: TextStyle(color: Colors.white54, fontSize: 11)),
        ),
      ]),
    );
  }

  Widget _buildGrid() {
    return Expanded(
      child: Center(
        child: AnimatedContainer(
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
                  final idx = row * 3 + col;
                  final highlighted = idx == _highlightedCell;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: highlighted
                            ? AppColors.primary
                            : const Color(0xFF0F1624),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: highlighted
                              ? AppColors.primary
                              : Colors.white.withOpacity(0.08),
                          width: 1.5,
                        ),
                        boxShadow: highlighted
                            ? [BoxShadow(
                                color: AppColors.primary.withOpacity(0.5),
                                blurRadius: 16,
                              )]
                            : null,
                      ),
                    ),
                  );
                }),
              ),
            )),
          ),
        ),
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
            label: 'MATCH',
            icon: Icons.check_rounded,
            color: const Color(0xFF10B981),
            onTap: () => _processResponse(true),
          )),
          const SizedBox(width: 12),
          Expanded(child: _ResponseButton(
            label: 'NO MATCH',
            icon: Icons.close_rounded,
            color: Colors.grey[600]!,
            onTap: () => _processResponse(false),
          )),
        ]),
      ),
    );
  }

  Widget _buildGameOver() {
    final accuracy = _accuracy;
    return Scaffold(
      backgroundColor: const Color(0xFF080D1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close_rounded, color: Colors.white54, size: 22),
              ),
              const SizedBox(height: 32),
              const Text('N-Back Results',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Center(
                child: Text('$_score',
                    style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w900)),
              ),
              Center(
                child: Text('pts',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14)),
              ),
              const SizedBox(height: 24),
              _StatRow('Hits', '$_hitCount'),
              _StatRow('False alarms', '$_falseAlarmCount'),
              _StatRow('Accuracy', '${accuracy.toStringAsFixed(0)}%'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B6FFF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF7B6FFF).withOpacity(0.3)),
                ),
                child: Text(_ratingLabel,
                    style: const TextStyle(color: Color(0xFF7B6FFF), fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
              Text(
                'N-Back performance correlates with fluid intelligence — the ability to reason through new problems.',
                style: TextStyle(color: Colors.grey[600], fontSize: 12, height: 1.5),
              ),
              const Spacer(),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: _playAgain,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Play Again'),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B6FFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
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

class _ResponseButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ResponseButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
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
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 14)),
        const Spacer(),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
