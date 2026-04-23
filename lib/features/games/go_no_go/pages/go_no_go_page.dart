import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/game_service.dart';

class GoNoGoPage extends StatefulWidget {
  final void Function(int score, int timeSeconds, bool completed, int levelReached, int mistakes)? onScoreSubmitted;

  const GoNoGoPage({super.key, this.onScoreSubmitted});

  @override
  State<GoNoGoPage> createState() => _GoNoGoPageState();
}

class _GoNoGoPageState extends State<GoNoGoPage> with SingleTickerProviderStateMixin {
  static const int _totalSeconds = 60;

  List<bool> _isGoTrial = [];
  int _trialIndex = 0;
  int _score = 0;
  int _secondsLeft = _totalSeconds;
  int _commissionErrors = 0;
  int _correctInhibitions = 0;
  int _correctGoCount = 0;
  int _totalGoTrials = 0;
  int _totalNoGoTrials = 0;

  bool _showStimulus = false;
  bool _tappedThisTrial = false;
  bool _gameOver = false;
  bool _submitting = false;
  double _flashOpacity = 0.0;
  Color? _ringColor;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  Timer? _countdownTimer;
  Timer? _stimulusTimer;
  Timer? _offTimer;
  Timer? _flashTimer;
  Timer? _ringTimer;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.05).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _generateSequence();
    _startGame();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _countdownTimer?.cancel();
    _stimulusTimer?.cancel();
    _offTimer?.cancel();
    _flashTimer?.cancel();
    _ringTimer?.cancel();
    super.dispose();
  }

  void _generateSequence() {
    final seed = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;
    final rng = Random(seed);
    // Estimate ~70 trials total; build more than enough
    final raw = List<bool>.generate(80, (_) => rng.nextDouble() < 0.8); // 80% go
    // Fix: never more than 3 consecutive go trials
    final fixed = <bool>[];
    int consecutive = 0;
    for (final t in raw) {
      if (t) {
        if (consecutive >= 3) {
          fixed.add(false);
          consecutive = 0;
        } else {
          fixed.add(true);
          consecutive++;
        }
      } else {
        fixed.add(false);
        consecutive = 0;
      }
    }
    _isGoTrial = fixed;
    _totalGoTrials = fixed.where((b) => b).length;
    _totalNoGoTrials = fixed.where((b) => !b).length;
  }

  void _startGame() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        _endGame();
      }
    });
    _scheduleNextStimulus();
  }

  int get _stimulusOnMs {
    final elapsed = _totalSeconds - _secondsLeft;
    if (elapsed < 20) return 600;
    if (elapsed < 40) return 500;
    return 400;
  }

  int get _stimulusOffMs {
    final elapsed = _totalSeconds - _secondsLeft;
    if (elapsed < 20) return 400;
    if (elapsed < 40) return 300;
    return 250;
  }

  void _scheduleNextStimulus() {
    if (_gameOver || _trialIndex >= _isGoTrial.length) return;

    _stimulusTimer = Timer(Duration(milliseconds: _stimulusOffMs), () {
      if (_gameOver || !mounted) return;
      setState(() {
        _showStimulus = true;
        _tappedThisTrial = false;
      });

      _offTimer = Timer(Duration(milliseconds: _stimulusOnMs), () {
        if (!mounted) return;
        // Check for no-go inhibition
        final isGo = _trialIndex < _isGoTrial.length ? _isGoTrial[_trialIndex] : true;
        if (!isGo && !_tappedThisTrial) {
          // Correct inhibition
          setState(() {
            _correctInhibitions++;
            _score += 8;
            _ringColor = const Color(0xFF10B981);
          });
          _ringTimer = Timer(const Duration(milliseconds: 200), () {
            if (mounted) setState(() => _ringColor = null);
          });
        } else if (isGo && !_tappedThisTrial) {
          // Omission
          setState(() => _score = max(0, _score - 5));
        }
        setState(() {
          _showStimulus = false;
          _trialIndex++;
        });
        _scheduleNextStimulus();
      });
    });
  }

  void _onTap() {
    if (!_showStimulus || _gameOver) return;
    final isGo = _trialIndex < _isGoTrial.length ? _isGoTrial[_trialIndex] : true;

    if (isGo) {
      setState(() {
        _correctGoCount++;
        _score += 10 + 3; // +3 bonus default
        _tappedThisTrial = true;
      });
      _showPulse();
    } else {
      // Commission error
      setState(() {
        _commissionErrors++;
        _score = max(0, _score - 20);
        _flashOpacity = 0.3;
        _tappedThisTrial = true;
      });
      _flashTimer = Timer(const Duration(milliseconds: 150), () {
        if (mounted) setState(() => _flashOpacity = 0.0);
      });
    }
  }

  void _showPulse() {
    // Handled via AnimatedScale briefly
    _pulseCtrl.forward(from: 0);
  }

  void _endGame() {
    _stimulusTimer?.cancel();
    _offTimer?.cancel();
    setState(() {
      _showStimulus = false;
      _gameOver = true;
    });
  }

  double get _commissionRate =>
      _totalNoGoTrials > 0 ? (_commissionErrors / _totalNoGoTrials * 100) : 0.0;

  String get _ratingLabel {
    final rate = _commissionRate;
    if (rate <= 5) return 'Elite Control';
    if (rate <= 15) return 'Strong';
    if (rate <= 30) return 'Average';
    return 'Impulsive';
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    await GameService.submitResult(
      gameType: 'go_no_go',
      score: _score,
      timePlayedSeconds: 60,
      completed: true,
      levelReached: _correctInhibitions,
      mistakes: _commissionErrors,
    );
    widget.onScoreSubmitted?.call(_score, 60, true, _correctInhibitions, _commissionErrors);
    if (mounted) Navigator.pop(context);
  }

  void _playAgain() {
    _countdownTimer?.cancel();
    _stimulusTimer?.cancel();
    _offTimer?.cancel();
    _flashTimer?.cancel();
    _ringTimer?.cancel();
    setState(() {
      _trialIndex = 0;
      _score = 0;
      _secondsLeft = _totalSeconds;
      _commissionErrors = 0;
      _correctInhibitions = 0;
      _correctGoCount = 0;
      _showStimulus = false;
      _tappedThisTrial = false;
      _gameOver = false;
      _submitting = false;
      _flashOpacity = 0.0;
      _ringColor = null;
    });
    _generateSequence();
    _startGame();
  }

  bool get _isGoSignal => _trialIndex < _isGoTrial.length && _isGoTrial[_trialIndex];

  @override
  Widget build(BuildContext context) {
    if (_gameOver) return _buildGameOver();

    return Scaffold(
      backgroundColor: const Color(0xFF080D1A),
      body: Stack(children: [
        // Commission error full-screen flash
        if (_flashOpacity > 0)
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _flashOpacity,
              duration: const Duration(milliseconds: 80),
              child: Container(color: const Color(0xFFEF4444)),
            ),
          ),
        SafeArea(
          child: Column(children: [
            _buildTopBar(),
            Expanded(child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _onTap,
              child: Center(child: _buildCircle()),
            )),
            Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Text('Tap GO — Hold for STOP',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.close_rounded, color: Colors.white54, size: 22),
        ),
        const SizedBox(width: 12),
        Text('${_secondsLeft}s',
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const Spacer(),
        Row(children: [
          const Icon(Icons.close_rounded, color: Color(0xFFEF4444), size: 14),
          const SizedBox(width: 4),
          Text('$_commissionErrors',
              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 14, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(width: 16),
        Text('$_score pts',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildCircle() {
    if (!_showStimulus) return const SizedBox(width: 200, height: 200);

    final isGo = _isGoSignal;
    final color = isGo ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final label = isGo ? 'GO' : '✕';

    return AnimatedScale(
      scale: _pulseAnim.value,
      duration: const Duration(milliseconds: 150),
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: _ringColor != null
              ? Border.all(color: _ringColor!, width: 4)
              : null,
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.4), blurRadius: 32, spreadRadius: 4)
          ],
        ),
        child: Center(
          child: Text(label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.bold,
              )),
        ),
      ),
    );
  }

  Widget _buildGameOver() {
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
              const Text('Inhibition Results',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Center(
                child: Text('$_score',
                    style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w900)),
              ),
              Center(child: Text('pts', style: TextStyle(color: Colors.grey[500], fontSize: 14))),
              const SizedBox(height: 24),
              _StatRow('Correct Go', '$_correctGoCount / $_totalGoTrials'),
              _StatRow('Correct Stops', '$_correctInhibitions / $_totalNoGoTrials'),
              _StatRow('Commission errors', '$_commissionErrors',
                  valueColor: const Color(0xFFEF4444)),
              _StatRow('Commission rate', '${_commissionRate.toStringAsFixed(0)}%',
                  valueColor: const Color(0xFFEF4444)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                ),
                child: Text(_ratingLabel,
                    style: const TextStyle(
                        color: Color(0xFF10B981), fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
              Text(
                'Commission errors reveal impulse control — the same faculty that helps you resist distractions and stick to your goals.',
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
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
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

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _StatRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 14)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
