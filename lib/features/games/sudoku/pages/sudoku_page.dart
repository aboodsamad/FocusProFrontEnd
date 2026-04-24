import 'dart:async';
import 'dart:math';
import 'package:capstone_front_end/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../features/home/providers/user_provider.dart';
import '../../services/game_service.dart';
import '../models/sudoku_model.dart';
import '../widgets/sudoku_board.dart';
import '../widgets/sudoku_header.dart';
import '../widgets/sudoku_number_pad.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colours — Deep Focus light theme
// ─────────────────────────────────────────────────────────────────────────────

const _kBg      = AppColors.surface;
const _kCardBg  = AppColors.surfaceContainerLowest;
const _kPrimary = AppColors.primary;

// ─────────────────────────────────────────────────────────────────────────────
// SudokuHomePage
// ─────────────────────────────────────────────────────────────────────────────

class SudokuHomePage extends StatefulWidget {
  const SudokuHomePage({super.key});
  @override
  State<SudokuHomePage> createState() => _SudokuHomePageState();
}

class _SudokuHomePageState extends State<SudokuHomePage>
    with SingleTickerProviderStateMixin {

  // ── Game state ─────────────────────────────────────────────────────────────

  List<List<int>>  board    = List.generate(9, (_) => List.filled(9, 0));
  List<List<int>>  solution = List.generate(9, (_) => List.filled(9, 0));
  List<List<bool>> isFixed  = List.generate(9, (_) => List.filled(9, false));

  int? selectedRow;
  int? selectedCol;

  int    mistakes  = 0;
  int    hintsUsed = 0;
  Timer? _timer;
  int    seconds   = 0;

  String difficulty = 'Medium';
  bool   gameWon    = false;

  late AnimationController _fadeController;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _startNewGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  // ── Timer ──────────────────────────────────────────────────────────────────

  void _startTimer() {
    _timer?.cancel();
    seconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => seconds++);
    });
  }

  void _stopTimer() => _timer?.cancel();

  String _formatTime(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  // ── New game ───────────────────────────────────────────────────────────────

  Future<void> _startNewGame() async {
    _stopTimer();
    setState(() {
      mistakes    = 0;
      hintsUsed   = 0;
      selectedRow = null;
      selectedCol = null;
      gameWon     = false;
    });
    await Future.microtask(() {
      final puzzle = _generatePuzzle();
      setState(() {
        board    = List.generate(9, (r) => List.generate(9, (c) => puzzle.board[r][c]));
        solution = List.generate(9, (r) => List.generate(9, (c) => puzzle.solution[r][c]));
        isFixed  = List.generate(9, (r) => List.generate(9, (c) => puzzle.board[r][c] != 0));
      });
    });
    _startTimer();
    _fadeController.forward(from: 0);
  }

  // ── Puzzle generation ──────────────────────────────────────────────────────

  SudokuPuzzle _generatePuzzle() {
    final rng  = Random();
    final full = List.generate(9, (_) => List.filled(9, 0));
    _fillBoard(full, rng);
    final sol    = List.generate(9, (r) => List.generate(9, (c) => full[r][c]));
    final remove = difficulty == 'Easy' ? 35 : (difficulty == 'Medium' ? 45 : 55);
    return SudokuPuzzle(_removeNumbers(full, remove, rng), sol);
  }

  bool _fillBoard(List<List<int>> b, Random rng) {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (b[r][c] == 0) {
          final nums = List.generate(9, (i) => i + 1)..shuffle(rng);
          for (final n in nums) {
            if (_isValid(b, r, c, n)) {
              b[r][c] = n;
              if (_fillBoard(b, rng)) return true;
              b[r][c] = 0;
            }
          }
          return false;
        }
      }
    }
    return true;
  }

  List<List<int>> _removeNumbers(List<List<int>> b, int count, Random rng) {
    final puzzle    = List.generate(9, (r) => List.generate(9, (c) => b[r][c]));
    final positions = List.generate(81, (i) => i)..shuffle(rng);
    int removed     = 0;
    for (final pos in positions) {
      if (removed >= count) break;
      final r = pos ~/ 9, c = pos % 9;
      if (puzzle[r][c] != 0) { puzzle[r][c] = 0; removed++; }
    }
    return puzzle;
  }

  bool _isValid(List<List<int>> b, int row, int col, int num) {
    for (int c = 0; c < 9; c++) if (b[row][c] == num) return false;
    for (int r = 0; r < 9; r++) if (b[r][col] == num) return false;
    final br = (row ~/ 3) * 3, bc = (col ~/ 3) * 3;
    for (int r = br; r < br + 3; r++) {
      for (int c = bc; c < bc + 3; c++) {
        if (b[r][c] == num) return false;
      }
    }
    return true;
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _selectCell(int row, int col) => setState(() {
    if (selectedRow == row && selectedCol == col) {
      selectedRow = selectedCol = null;
    } else {
      selectedRow = row;
      selectedCol = col;
    }
  });

  void _placeNumber(int number) {
    if (selectedRow == null || selectedCol == null || gameWon) return;
    if (isFixed[selectedRow!][selectedCol!]) return;
    setState(() {
      board[selectedRow!][selectedCol!] = number;
      if (solution[selectedRow!][selectedCol!] != number) mistakes++;
      if (_isPuzzleComplete()) _onWin();
    });
  }

  void _eraseCell() {
    if (selectedRow == null || selectedCol == null) return;
    if (isFixed[selectedRow!][selectedCol!]) return;
    setState(() => board[selectedRow!][selectedCol!] = 0);
  }

  void _useHint() {
    if (selectedRow == null || selectedCol == null || gameWon) return;
    if (isFixed[selectedRow!][selectedCol!]) return;
    setState(() {
      board[selectedRow!][selectedCol!] = solution[selectedRow!][selectedCol!];
      hintsUsed++;
      if (_isPuzzleComplete()) _onWin();
    });
  }

  bool _isPuzzleComplete() {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (board[r][c] == 0 || board[r][c] != solution[r][c]) return false;
      }
    }
    return true;
  }

  /// Normalized score 0-1000: accuracy × time efficiency × difficulty.
  /// Not completed → small partial score based on difficulty only.
  int _calculateNormalizedScore() {
    if (!gameWon) {
      // Partial credit for attempting: 0 / 100 / 150 for easy/medium/hard
      final partial = difficulty == 'Easy' ? 0 : difficulty == 'Medium' ? 100 : 150;
      return partial;
    }
    final diffMult     = difficulty == 'Easy' ? 1.0 : difficulty == 'Medium' ? 1.5 : 2.0;
    final accuracyFact = (1.0 - mistakes * 0.1).clamp(0.2, 1.0);
    final timeEff      = (1.0 - seconds / 1200.0).clamp(0.3, 1.0);
    return (accuracyFact * timeEff * diffMult * 600).round().clamp(0, 1000);
  }

  void _onWin() {
    gameWon = true;
    _stopTimer();
    _showWinDialog();
    _submitResult();
  }

  Future<void> _submitResult() async {
    final result = await GameService.submitResult(
      gameType:          'sudoku',
      score:             _calculateNormalizedScore(),
      timePlayedSeconds: seconds,
      completed:         gameWon,
      mistakes:          mistakes,
    );
    if (result != null && mounted) {
      context.read<UserProvider>().updateFocusScore(result.newFocusScore);
    }
  }

  // ── Win dialog ─────────────────────────────────────────────────────────────

  void _showWinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (_) => Dialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72, height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondaryContainer,
                ),
                child: const Icon(Icons.emoji_events_rounded,
                    color: AppColors.primary, size: 36),
              ),
              const SizedBox(height: 18),
              const Text('Puzzle Solved!',
                  style: TextStyle(color: AppColors.onSurface, fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Great job keeping focused',
                  style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13)),
              const SizedBox(height: 20),
              const Divider(color: AppColors.outlineVariant),
              const SizedBox(height: 16),
              SudokuStatRow(icon: Icons.timer_outlined,
                  label: 'Time',     value: _formatTime(seconds)),
              SudokuStatRow(icon: Icons.error_outline_rounded,
                  label: 'Mistakes', value: mistakes.toString()),
              SudokuStatRow(icon: Icons.lightbulb_outline_rounded,
                  label: 'Hints',    value: hintsUsed.toString()),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton(
                  onPressed: () { Navigator.pop(context); _startNewGame(); },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                  ),
                  child: const Text('New Game',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close',
                    style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  // The digit currently in the selected cell (0 if nothing selected or cell empty)
  int get _selectedValue =>
      (selectedRow != null && selectedCol != null)
          ? board[selectedRow!][selectedCol!]
          : 0;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // Submit partial result if a game is in progress and not yet won
        if (!gameWon && seconds > 0) {
          _stopTimer();
          await _submitResult();
        }
        if (mounted) Navigator.pop(context);
      },
      child: Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color:        AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: AppColors.onSurface, size: 16),
                  ),
                ),
                const SizedBox(width: 14),
                const Text('Sudoku',
                    style: TextStyle(color: AppColors.onSurface, fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                GestureDetector(
                  onTap: _startNewGame,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color:        AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(children: [
                      Icon(Icons.refresh_rounded, color: AppColors.primary, size: 16),
                      SizedBox(width: 5),
                      Text('New', style: TextStyle(color: AppColors.primary,
                          fontSize: 13, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ),
              ]),
            ),

            // ── Stats row ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SudokuInfoCard(
                      icon: Icons.timer_outlined,
                      text: _formatTime(seconds)),
                  SudokuDifficultySelector(
                      difficulty: difficulty,
                      onSelected: (v) {
                        setState(() => difficulty = v);
                        _startNewGame();
                      }),
                  SudokuInfoCard(
                      icon:      Icons.close_rounded,
                      text:      mistakes.toString(),
                      iconColor: mistakes > 0
                          ? AppColors.error
                          : AppColors.onSurfaceVariant),
                ],
              ),
            ),

            // ── Board ──────────────────────────────────────────────────────
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: FadeTransition(
                      opacity: _fadeController,
                      child: SudokuBoard(
                        board:       board,
                        solution:    solution,
                        isFixed:     isFixed,
                        selectedRow: selectedRow,
                        selectedCol: selectedCol,
                        onCellTap:   _selectCell,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Number pad ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerLowest,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SudokuNumberPad(
                    board:           board,
                    selectedValue:   _selectedValue,
                    onNumberPressed: _placeNumber,
                  ),
                  const SizedBox(height: 12),
                  SudokuActionButtons(onHint: _useHint, onErase: _eraseCell),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    )); // PopScope
  }
}
