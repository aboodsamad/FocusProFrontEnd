import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../features/home/providers/user_provider.dart';
import '../../services/game_service.dart';
import '../models/memory_matrix_model.dart';
import '../widgets/memory_matrix_grid.dart';
import '../widgets/memory_matrix_header.dart';
import '../widgets/memory_matrix_idle_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MemoryMatrixPage
// ─────────────────────────────────────────────────────────────────────────────

class MemoryMatrixPage extends StatefulWidget {
  const MemoryMatrixPage({super.key});

  @override
  State<MemoryMatrixPage> createState() => _MemoryMatrixPageState();
}

class _MemoryMatrixPageState extends State<MemoryMatrixPage>
    with TickerProviderStateMixin {

  // ── Colors ─────────────────────────────────────────────────────────────────

  static const Color _bg        = Color(0xFF06090F);
  static const Color _accent    = Color(0xFF5B8FFF);
  static const Color _gold      = Color(0xFFFFD166);
  static const Color _wrong     = Color(0xFFFF5270);
  static const Color _textMuted = Color(0xFF6B7A99);

  // ── Grid size ──────────────────────────────────────────────────────────────

  /// Level 1 → 9×9, level 2 → 10×10, …, level 5+ → 13×13 (max).
  int get _currentGridSize => MemoryMatrixState.gridSizeForLevel(_game.level);

  // ── State ──────────────────────────────────────────────────────────────────

  late MemoryMatrixState _game;
  DateTime? _gameStartTime;

  /// Tracks how many cells we've allocated controllers for.
  int _allocatedGridSize = 0;

  /// Periodic timer that counts down during the input phase.
  Timer? _inputTimer;

  // ── Animations ─────────────────────────────────────────────────────────────

  late AnimationController _fadeCtrl;
  late AnimationController _scaleCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<double>   _scaleAnim;

  final Map<int, AnimationController> _cellCtrl = {};
  final Map<int, Animation<double>>   _cellAnim = {};

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    const initialGridSize = 9; // level 1
    _game = MemoryMatrixState.initial(initialGridSize);

    _fadeCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 400),
    )..forward();

    _scaleCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnim  = CurvedAnimation(parent: _fadeCtrl,  curve: Curves.easeOut);
    _scaleAnim = CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut);

    _rebuildCellControllers(initialGridSize);
  }

  @override
  void dispose() {
    _inputTimer?.cancel();
    _fadeCtrl.dispose();
    _scaleCtrl.dispose();
    for (final c in _cellCtrl.values) c.dispose();
    super.dispose();
  }

  // ── Cell-controller management ─────────────────────────────────────────────

  void _rebuildCellControllers(int gridSize) {
    for (final c in _cellCtrl.values) c.dispose();
    _cellCtrl.clear();
    _cellAnim.clear();
    for (int i = 0; i < gridSize * gridSize; i++) {
      final ctrl = AnimationController(
        vsync:    this,
        duration: const Duration(milliseconds: 250),
      );
      _cellCtrl[i] = ctrl;
      _cellAnim[i] = Tween<double>(begin: 0.0, end: 1.0)
          .animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOut));
    }
    _allocatedGridSize = gridSize;
  }

  void _ensureCellControllers(int gridSize) {
    if (_allocatedGridSize != gridSize) _rebuildCellControllers(gridSize);
  }

  // ── Input timer ────────────────────────────────────────────────────────────

  void _startInputTimer() {
    _inputTimer?.cancel();
    final seconds = MemoryMatrixState.inputSecondsForLevel(_game.level);
    setState(() => _game = _game.copyWith(timeLeft: seconds));

    _inputTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      final remaining = _game.timeLeft - 1;
      if (remaining <= 0) {
        timer.cancel();
        setState(() => _game = _game.copyWith(timeLeft: 0));
        _submitAnswer(); // auto-submit on timeout
      } else {
        setState(() => _game = _game.copyWith(timeLeft: remaining));
      }
    });
  }

  void _cancelInputTimer() {
    _inputTimer?.cancel();
    _inputTimer = null;
  }

  // ── Game flow ──────────────────────────────────────────────────────────────

  void _startGame() {
    HapticFeedback.mediumImpact();
    _cancelInputTimer();
    _gameStartTime = DateTime.now();
    const startLevel = 1;
    final gs = MemoryMatrixState.gridSizeForLevel(startLevel);
    _ensureCellControllers(gs);
    setState(() {
      _game = MemoryMatrixState.initial(gs).copyWith(
        phase: MemoryMatrixPhase.countdown,
      );
    });
    _runCountdown();
  }

  Future<void> _runCountdown() async {
    for (int i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() => _game = _game.copyWith(countdownValue: i));
      await Future.delayed(const Duration(milliseconds: 900));
    }
    _startRound();
  }

  void _startRound() {
    final gs = _currentGridSize;
    _ensureCellControllers(gs);
    final pattern    = _buildPattern(gs);
    final inputSecs  = MemoryMatrixState.inputSecondsForLevel(_game.level);
    setState(() {
      _game = _game.copyWith(
        phase:            MemoryMatrixPhase.showing,
        pattern:          pattern,
        playerInput:      List.generate(gs, (_) => List.filled(gs, false)),
        highlightedCells: {},
        timeLeft:         inputSecs,
      );
    });
    _showPattern(gs);
  }

  List<List<bool>> _buildPattern(int gs) {
    final count   = _game.cellsToRemember(gs);
    final indices = List.generate(gs * gs, (i) => i)..shuffle(Random());
    final pattern = List.generate(gs, (_) => List.filled(gs, false));
    for (int i = 0; i < count; i++) {
      pattern[indices[i] ~/ gs][indices[i] % gs] = true;
    }
    return pattern;
  }

  Future<void> _showPattern(int gs) async {
    final patternIndices = <int>[];
    for (int r = 0; r < gs; r++) {
      for (int c = 0; c < gs; c++) {
        if (_game.pattern[r][c]) patternIndices.add(r * gs + c);
      }
    }
    // Randomise reveal order for unpredictability
    patternIndices.shuffle(Random());

    // Reveal delay shortens on bigger grids so total reveal time stays reasonable
    final revealDelayMs = gs >= 12 ? 90 : gs >= 10 ? 110 : 130;

    final highlighted = <int>{};
    for (final idx in patternIndices) {
      if (!mounted) return;
      highlighted.add(idx);
      setState(() => _game = _game.copyWith(highlightedCells: Set.of(highlighted)));
      _cellCtrl[idx]!.forward(from: 0.0);
      HapticFeedback.selectionClick();
      await Future.delayed(Duration(milliseconds: revealDelayMs));
    }

    // Hold: shorter at higher levels to increase difficulty
    final holdMs = max(400, 1800 - (_game.level * 120));
    await Future.delayed(Duration(milliseconds: holdMs));
    if (!mounted) return;

    for (final idx in patternIndices) _cellCtrl[idx]!.reverse();
    await Future.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;

    setState(() => _game = _game.copyWith(
      highlightedCells: {},
      phase:            MemoryMatrixPhase.input,
    ));
    _startInputTimer();
  }

  void _onCellTap(int row, int col) {
    if (_game.phase != MemoryMatrixPhase.input) return;
    HapticFeedback.selectionClick();
    final gs = _currentGridSize;

    final updated = List.generate(
      gs,
      (r) => List.generate(gs, (c) => _game.playerInput[r][c]),
    );
    updated[row][col] = !updated[row][col];
    setState(() => _game = _game.copyWith(playerInput: updated));

    final idx = row * gs + col;
    if (updated[row][col]) {
      _cellCtrl[idx]!.forward(from: 0.0);
    } else {
      _cellCtrl[idx]!.reverse();
    }
  }

  Future<void> _submitAnswer() async {
    if (_game.phase != MemoryMatrixPhase.input) return;
    _cancelInputTimer();
    HapticFeedback.mediumImpact();

    final gs = _currentGridSize;
    final revealSet = <int>{};
    bool allCorrect = true;
    for (int r = 0; r < gs; r++) {
      for (int c = 0; c < gs; c++) {
        if (_game.pattern[r][c]) revealSet.add(r * gs + c);
        if (_game.pattern[r][c] != _game.playerInput[r][c]) allCorrect = false;
      }
    }
    setState(() => _game = _game.copyWith(
      phase:            MemoryMatrixPhase.checking,
      highlightedCells: revealSet,
    ));

    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;

    for (final ctrl in _cellCtrl.values) ctrl.reset();

    if (allCorrect) {
      final newScore = _game.score + _game.roundPoints(gs);
      final newLevel = _game.level + 1;
      final newGs    = MemoryMatrixState.gridSizeForLevel(newLevel);
      _ensureCellControllers(newGs);
      setState(() => _game = _game.copyWith(
        score:            newScore,
        level:            newLevel,
        phase:            MemoryMatrixPhase.levelUp,
        highlightedCells: {},
      ));
      _scaleCtrl.forward(from: 0.0);
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 1600));
      if (!mounted) return;
      _startRound();
    } else {
      final newLives = _game.lives - 1;
      HapticFeedback.vibrate();
      if (newLives <= 0) {
        setState(() => _game = _game.copyWith(
          lives:            0,
          phase:            MemoryMatrixPhase.gameOver,
          highlightedCells: {},
        ));
        _fadeCtrl.forward(from: 0.0);
        _submitGameResult();
      } else {
        setState(() => _game = _game.copyWith(
          lives:            newLives,
          highlightedCells: {},
        ));
        _startRound();
      }
    }
  }

  // ── Submit result to backend ───────────────────────────────────────────────

  Future<void> _submitGameResult() async {
    final timePlayed = _gameStartTime != null
        ? DateTime.now().difference(_gameStartTime!).inSeconds
        : 0;
    final result = await GameService.submitResult(
      gameType:          'memory_matrix',
      score:             _game.score,
      timePlayedSeconds: timePlayed,
      completed:         false,
      levelReached:      _game.level,
    );
    if (result != null && mounted) {
      context.read<UserProvider>().updateFocusScore(result.newFocusScore);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  // ── App bar ────────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    final showStats = _game.phase != MemoryMatrixPhase.idle &&
        _game.phase != MemoryMatrixPhase.gameOver;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          _BackButton(onTap: () => Navigator.pop(context)),
          const Spacer(),
          if (showStats) MemoryMatrixScoreChip(score: _game.score, level: _game.level),
          const Spacer(),
          if (showStats)
            MemoryMatrixLivesRow(lives: _game.lives)
          else
            const SizedBox(width: 40),
        ],
      ),
    );
  }

  // ── Body router ────────────────────────────────────────────────────────────

  Widget _buildBody() {
    switch (_game.phase) {
      case MemoryMatrixPhase.idle:
        return FadeTransition(
          opacity: _fadeAnim,
          child: MemoryMatrixIdleScreen(onStart: _startGame),
        );

      case MemoryMatrixPhase.countdown:
        return _buildCountdownScreen();

      case MemoryMatrixPhase.levelUp:
        return _buildLevelUpScreen();

      case MemoryMatrixPhase.gameOver:
        return FadeTransition(
          opacity: _fadeAnim,
          child: _buildGameOverScreen(),
        );

      default:
        return _buildGameScreen();
    }
  }

  // ── Countdown ──────────────────────────────────────────────────────────────

  Widget _buildCountdownScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${_game.countdownValue}',
            style: const TextStyle(
              color:       _accent,
              fontSize:    96,
              fontWeight:  FontWeight.w800,
              letterSpacing: -4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Get ready...',
            style: TextStyle(color: _textMuted, fontSize: 16),
          ),
        ],
      ),
    );
  }

  // ── Active game (showing / input / checking) ───────────────────────────────

  Widget _buildGameScreen() {
    final gs = _currentGridSize;
    final needed = _game.cellsToRemember(gs);
    final totalSecs = MemoryMatrixState.inputSecondsForLevel(_game.level);

    final label = switch (_game.phase) {
      MemoryMatrixPhase.showing  => 'Watch carefully...',
      MemoryMatrixPhase.input    => 'Select $needed cells',
      MemoryMatrixPhase.checking => 'Checking...',
      _                          => '',
    };

    return Column(
      children: [
        const SizedBox(height: 12),
        // Status label + timer on same row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: MemoryMatrixStatusLabel(key: ValueKey(label), text: label),
              ),
              if (_game.phase == MemoryMatrixPhase.input) ...[
                const SizedBox(width: 16),
                MemoryMatrixTimerRing(
                  timeLeft:  _game.timeLeft,
                  totalTime: totalSecs,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AspectRatio(
                aspectRatio: 1,
                child: MemoryMatrixGrid(
                  gridSize:         gs,
                  phase:            _game.phase,
                  pattern:          _game.pattern,
                  playerInput:      _game.playerInput,
                  highlightedCells: _game.highlightedCells,
                  cellAnimations:   _cellAnim,
                  onCellTap:        _onCellTap,
                ),
              ),
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _game.phase == MemoryMatrixPhase.input
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: _SubmitButton(
                    selected: _game.selectedCount,
                    required: needed,
                    onTap:    _game.selectedCount == needed ? _submitAnswer : null,
                  ),
                )
              : const SizedBox(height: 72),
        ),
      ],
    );
  }

  // ── Level up ───────────────────────────────────────────────────────────────

  Widget _buildLevelUpScreen() {
    final prevGs = MemoryMatrixState.gridSizeForLevel(_game.level - 1);
    return Center(
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width:  90,
              height: 90,
              decoration: BoxDecoration(
                shape:    BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xFFFFD166), Color(0xFFFF9A3C)],
                ),
                boxShadow: [
                  BoxShadow(
                    color:      _gold.withOpacity(0.4),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.star_rounded, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 20),
            const Text(
              'Level Up!',
              style: TextStyle(
                color:       Colors.white,
                fontSize:    34,
                fontWeight:  FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Now on level ${_game.level}',
              style: const TextStyle(color: _textMuted, fontSize: 16),
            ),
            if (_currentGridSize > prevGs) ...[
              const SizedBox(height: 6),
              Text(
                'Grid grew to ${_currentGridSize}×${_currentGridSize}!',
                style: const TextStyle(color: _accent, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              '+${_game.roundPoints(prevGs)} pts',
              style: const TextStyle(
                color:      _gold,
                fontSize:   20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Game over ──────────────────────────────────────────────────────────────

  Widget _buildGameOverScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width:  88,
              height: 88,
              decoration: BoxDecoration(
                shape:  BoxShape.circle,
                color:  _wrong.withOpacity(0.12),
                border: Border.all(color: _wrong.withOpacity(0.3), width: 1.5),
              ),
              child: const Icon(Icons.close_rounded, color: _wrong, size: 44),
            ),
            const SizedBox(height: 24),
            const Text(
              'Game Over',
              style: TextStyle(
                color:       Colors.white,
                fontSize:    32,
                fontWeight:  FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 28),
            MemoryMatrixStatRow(
              label:      'Final Score',
              value:      '${_game.score} pts',
              valueColor: _accent,
            ),
            const SizedBox(height: 8),
            MemoryMatrixStatRow(
              label:      'Level Reached',
              value:      '${_game.level}',
              valueColor: _gold,
            ),
            const SizedBox(height: 48),
            _PrimaryButton(label: 'Play Again', onTap: _startGame),
            const SizedBox(height: 12),
            _SecondaryButton(label: 'Exit', onTap: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small private widgets  (page-specific — not reused elsewhere)
// ─────────────────────────────────────────────────────────────────────────────

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width:  40,
      height: 40,
      decoration: BoxDecoration(
        color:        const Color(0xFF0F1420),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: const Color(0xFF1E2840)),
      ),
      child: const Icon(
        Icons.arrow_back_ios_new_rounded,
        color: Colors.white,
        size:  16,
      ),
    ),
  );
}

class _SubmitButton extends StatelessWidget {
  final int          selected;
  final int          required;
  final VoidCallback? onTap;

  const _SubmitButton({
    required this.selected,
    required this.required,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ready = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width:    double.infinity,
        padding:  const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: ready
              ? const LinearGradient(
                  colors: [Color(0xFF3D6EFF), Color(0xFF5B8FFF)],
                )
              : null,
          color:         ready ? null : const Color(0xFF0F1420),
          borderRadius:  BorderRadius.circular(16),
          border:        ready ? null : Border.all(color: const Color(0xFF1E2840)),
          boxShadow: ready
              ? [BoxShadow(
                  color:  const Color(0xFF5B8FFF).withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )]
              : null,
        ),
        child: Center(
          child: Text(
            ready
                ? 'Submit Answer'
                : 'Select $selected / $required cells',
            style: TextStyle(
              color:       ready ? Colors.white : const Color(0xFF6B7A99),
              fontWeight:  FontWeight.w700,
              fontSize:    16,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width:   double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3D6EFF), Color(0xFF5B8FFF)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:  const Color(0xFF5B8FFF).withOpacity(0.4),
            blurRadius:  24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color:       Colors.white,
            fontWeight:  FontWeight.w700,
            fontSize:    16,
            letterSpacing: 0.3,
          ),
        ),
      ),
    ),
  );
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SecondaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width:   double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color:        const Color(0xFF0F1420),
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: const Color(0xFF1E2840)),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color:      Color(0xFF6B7A99),
            fontWeight: FontWeight.w600,
            fontSize:   15,
          ),
        ),
      ),
    ),
  );
}
