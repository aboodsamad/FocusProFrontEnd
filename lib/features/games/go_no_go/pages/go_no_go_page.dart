import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../services/game_service.dart';

const _kGo    = Color(0xFF10B981);
const _kNoGo  = Color(0xFFEF4444);

class GoNoGoPage extends StatefulWidget {
  final void Function(int score, int timeSeconds, bool completed, int levelReached, int mistakes)? onScoreSubmitted;

  const GoNoGoPage({super.key, this.onScoreSubmitted});

  @override
  State<GoNoGoPage> createState() => _GoNoGoPageState();
}

class _GoNoGoPageState extends State<GoNoGoPage> with SingleTickerProviderStateMixin {
  static const int _totalSeconds = 60;

  List<bool> _isGoTrial = [];
  int  _trialIndex          = 0;
  int  _score               = 0;
  int  _secondsLeft         = _totalSeconds;
  int  _commissionErrors    = 0;
  int  _correctInhibitions  = 0;
  int  _correctGoCount      = 0;
  int  _totalGoTrials       = 0;
  int  _totalNoGoTrials     = 0;

  bool   _showStimulus   = false;
  bool   _tappedThisTrial = false;
  bool   _gameOver       = false;
  bool   _submitting     = false;
  double _flashOpacity   = 0.0;
  Color? _ringColor;

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  Timer? _countdownTimer;
  Timer? _stimulusTimer;
  Timer? _offTimer;
  Timer? _flashTimer;
  Timer? _ringTimer;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300))
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
    final rng  = Random(seed);
    final raw  = List<bool>.generate(80, (_) => rng.nextDouble() < 0.8);
    final fixed = <bool>[];
    int consecutive = 0;
    for (final t in raw) {
      if (t && consecutive >= 3) { fixed.add(false); consecutive = 0; }
      else { fixed.add(t); consecutive = t ? consecutive + 1 : 0; }
    }
    _isGoTrial       = fixed;
    _totalGoTrials   = fixed.where((b) => b).length;
    _totalNoGoTrials = fixed.where((b) => !b).length;
  }

  void _startGame() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) { t.cancel(); _endGame(); }
    });
    _scheduleNextStimulus();
  }

  int get _stimulusOnMs  => _secondsLeft > 40 ? 600 : _secondsLeft > 20 ? 500 : 400;
  int get _stimulusOffMs => _secondsLeft > 40 ? 400 : _secondsLeft > 20 ? 300 : 250;

  void _scheduleNextStimulus() {
    if (_gameOver || _trialIndex >= _isGoTrial.length) return;
    _stimulusTimer = Timer(Duration(milliseconds: _stimulusOffMs), () {
      if (_gameOver || !mounted) return;
      setState(() { _showStimulus = true; _tappedThisTrial = false; });
      _offTimer = Timer(Duration(milliseconds: _stimulusOnMs), () {
        if (!mounted) return;
        final isGo = _trialIndex < _isGoTrial.length ? _isGoTrial[_trialIndex] : true;
        if (!isGo && !_tappedThisTrial) {
          setState(() { _correctInhibitions++; _score += 8; _ringColor = _kGo; });
          _ringTimer = Timer(const Duration(milliseconds: 200), () {
            if (mounted) setState(() => _ringColor = null);
          });
        } else if (isGo && !_tappedThisTrial) {
          setState(() => _score = max(0, _score - 5));
        }
        setState(() { _showStimulus = false; _trialIndex++; });
        _scheduleNextStimulus();
      });
    });
  }

  void _onTap() {
    if (!_showStimulus || _gameOver) return;
    final isGo = _trialIndex < _isGoTrial.length ? _isGoTrial[_trialIndex] : true;
    if (isGo) {
      setState(() { _correctGoCount++; _score += 13; _tappedThisTrial = true; });
      _pulseCtrl.forward(from: 0);
    } else {
      setState(() {
        _commissionErrors++;
        _score       = max(0, _score - 20);
        _flashOpacity = 0.25;
        _tappedThisTrial = true;
      });
      _flashTimer = Timer(const Duration(milliseconds: 150), () {
        if (mounted) setState(() => _flashOpacity = 0.0);
      });
    }
  }

  void _endGame() {
    _stimulusTimer?.cancel();
    _offTimer?.cancel();
    setState(() { _showStimulus = false; _gameOver = true; });
  }

  double get _commissionRate =>
      _totalNoGoTrials > 0 ? (_commissionErrors / _totalNoGoTrials * 100) : 0.0;

  String get _ratingLabel {
    final r = _commissionRate;
    if (r <= 5) return 'Elite Control';
    if (r <= 15) return 'Strong';
    if (r <= 30) return 'Average';
    return 'Impulsive';
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    // Normalized score 0-1000: inhibition rate = correct holds / total hold attempts
    final int total = _correctInhibitions + _commissionErrors;
    final double inhibitionRate = total > 0 ? _correctInhibitions / total : 0.5;
    final int normalizedScore = (inhibitionRate * 1000).round().clamp(0, 1000);
    await GameService.submitResult(
      gameType: 'go_no_go', score: normalizedScore,
      timePlayedSeconds: 60, completed: true,
      levelReached: _correctInhibitions, mistakes: _commissionErrors,
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
      _trialIndex = 0; _score = 0; _secondsLeft = _totalSeconds;
      _commissionErrors = 0; _correctInhibitions = 0; _correctGoCount = 0;
      _showStimulus = false; _tappedThisTrial = false;
      _gameOver = false; _submitting = false;
      _flashOpacity = 0.0; _ringColor = null;
    });
    _generateSequence();
    _startGame();
  }

  bool get _isGoSignal =>
      _trialIndex < _isGoTrial.length && _isGoTrial[_trialIndex];

  @override
  Widget build(BuildContext context) {
    if (_gameOver) return _buildGameOver();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(children: [
        // Commission error flash overlay
        if (_flashOpacity > 0)
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _flashOpacity,
              duration: const Duration(milliseconds: 80),
              child: Container(color: _kNoGo.withOpacity(0.6)),
            ),
          ),
        SafeArea(child: Column(children: [
          _buildTopBar(),
          Expanded(child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onTap,
            child: Center(child: _buildCircle()),
          )),
          Padding(
            padding: const EdgeInsets.only(bottom: 28),
            child: Text('Tap GO · Resist STOP',
                style: const TextStyle(
                    color: AppColors.onSurfaceVariant, fontSize: 13)),
          ),
        ])),
      ]),
    );
  }

  Widget _buildTopBar() {
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
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Go / No-Go',
              style: TextStyle(color: AppColors.onSurface,
                  fontSize: 15, fontWeight: FontWeight.bold)),
          Text('${_secondsLeft}s remaining',
              style: TextStyle(
                  color: _secondsLeft <= 10 ? _kNoGo : AppColors.onSurfaceVariant,
                  fontSize: 11)),
        ])),
        // Commission errors badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _commissionErrors > 0 ? _kNoGo.withOpacity(0.1) : AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _commissionErrors > 0 ? _kNoGo.withOpacity(0.4) : AppColors.outlineVariant),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.close_rounded, color: _kNoGo, size: 12),
            const SizedBox(width: 3),
            Text('$_commissionErrors',
                style: TextStyle(color: _kNoGo, fontSize: 12, fontWeight: FontWeight.bold)),
          ]),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _kGo.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kGo.withOpacity(0.25)),
          ),
          child: Text('$_score pts',
              style: const TextStyle(
                  color: _kGo, fontSize: 14, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  Widget _buildCircle() {
    if (!_showStimulus) {
      // blank inter-stimulus circle outline
      return Container(
        width: 200, height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceContainerLow,
          border: Border.all(color: AppColors.outlineVariant, width: 2),
        ),
      );
    }
    final isGo = _isGoSignal;
    final color = isGo ? _kGo : _kNoGo;
    return AnimatedScale(
      scale: _pulseAnim.value,
      duration: const Duration(milliseconds: 150),
      child: Container(
        width: 200, height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: _ringColor != null
              ? Border.all(color: _ringColor!, width: 5)
              : null,
          boxShadow: [BoxShadow(
            color: color.withOpacity(0.35), blurRadius: 28, spreadRadius: 4)],
        ),
        child: Center(child: Text(
          isGo ? 'GO' : '✕',
          style: const TextStyle(
              color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
        )),
      ),
    );
  }

  Widget _buildGameOver() {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(child: Column(children: [
        // Header
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            border: Border(bottom: BorderSide(
                color: AppColors.outlineVariant.withOpacity(0.5))),
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
            const Text('Inhibition Results',
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
                    color: _kGo.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _kGo.withOpacity(0.25)),
                  ),
                  child: Text(_ratingLabel,
                      style: const TextStyle(color: _kGo,
                          fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            // Stats
            _StatsCard(children: [
              _StatRow('Correct Go', '$_correctGoCount / $_totalGoTrials'),
              _StatRow('Correct Stops', '$_correctInhibitions / $_totalNoGoTrials'),
              _StatRow('Commission errors', '$_commissionErrors',
                  valueColor: _kNoGo),
              _StatRow('Commission rate',
                  '${_commissionRate.toStringAsFixed(0)}%',
                  valueColor: _kNoGo),
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
                  'Commission errors reveal impulse control — the same faculty that helps you resist distractions and stick to your goals.',
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
      ])),
    );
  }
}

// ── Shared sub-widgets ─────────────────────────────────────────────────────────

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
