import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../features/home/providers/user_provider.dart';
import '../../services/game_service.dart';
import '../models/sudoku_model.dart';
import '../widgets/sudoku_board.dart';
import '../widgets/sudoku_header.dart';
import '../widgets/sudoku_number_pad.dart';

void main() => runApp(const SudokuApp());

// ─────────────────────────────────────────────────────────────────────────────
// App shell
// ─────────────────────────────────────────────────────────────────────────────

class SudokuApp extends StatelessWidget {
  const SudokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sudoku',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const SudokuHomePage(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Home page
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

  // ── Stats ──────────────────────────────────────────────────────────────────

  int    mistakes   = 0;
  int    hintsUsed  = 0;
  Timer? timer;
  int    seconds    = 0;

  String difficulty = 'Medium';
  bool   gameWon    = false;

  late AnimationController _animationController;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _startNewGame();
  }

  @override
  void dispose() {
    timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  // ── Timer helpers ──────────────────────────────────────────────────────────

  void _startTimer() {
    timer?.cancel();
    seconds = 0;
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => seconds++);
    });
  }

  void _stopTimer() => timer?.cancel();

  String _formatTime(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final secs    = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  // ── Game lifecycle ─────────────────────────────────────────────────────────

  Future<void> _startNewGame() async {
    _stopTimer();
    setState(() {
      mistakes   = 0;
      hintsUsed  = 0;
      selectedRow = null;
      selectedCol = null;
      gameWon    = false;
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
    _animationController.forward(from: 0);
  }

  // ── Puzzle generation (pure Dart logic) ───────────────────────────────────

  SudokuPuzzle _generatePuzzle() {
    final random    = Random();
    final fullBoard = List.generate(9, (_) => List.filled(9, 0));

    _fillBoard(fullBoard, random);

    final solutionBoard    = List.generate(9, (r) => List.generate(9, (c) => fullBoard[r][c]));
    final numbersToRemove  = difficulty == 'Easy' ? 35 : (difficulty == 'Medium' ? 45 : 55);
    final puzzleBoard      = _removeNumbers(fullBoard, numbersToRemove, random);

    return SudokuPuzzle(puzzleBoard, solutionBoard);
  }

  bool _fillBoard(List<List<int>> board, Random random) {
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        if (board[row][col] == 0) {
          final numbers = List.generate(9, (i) => i + 1)..shuffle(random);
          for (final num in numbers) {
            if (_isValid(board, row, col, num)) {
              board[row][col] = num;
              if (_fillBoard(board, random)) return true;
              board[row][col] = 0;
            }
          }
          return false;
        }
      }
    }
    return true;
  }

  List<List<int>> _removeNumbers(List<List<int>> board, int count, Random random) {
    final puzzle    = List.generate(9, (r) => List.generate(9, (c) => board[r][c]));
    final positions = <int>[];
    for (int i = 0; i < 81; i++) positions.add(i);
    positions.shuffle(random);

    int removed = 0;
    for (final pos in positions) {
      if (removed >= count) break;
      final row = pos ~/ 9;
      final col = pos % 9;
      if (puzzle[row][col] != 0) {
        puzzle[row][col] = 0;
        removed++;
      }
    }
    return puzzle;
  }

  bool _isValid(List<List<int>> board, int row, int col, int num) {
    for (int c = 0; c < 9; c++) {
      if (board[row][c] == num) return false;
    }
    for (int r = 0; r < 9; r++) {
      if (board[r][col] == num) return false;
    }
    final boxRow = (row ~/ 3) * 3;
    final boxCol = (col ~/ 3) * 3;
    for (int r = boxRow; r < boxRow + 3; r++) {
      for (int c = boxCol; c < boxCol + 3; c++) {
        if (board[r][c] == num) return false;
      }
    }
    return true;
  }

  // ── Game actions ───────────────────────────────────────────────────────────

  void _selectCell(int row, int col) {
    setState(() {
      if (selectedRow == row && selectedCol == col) {
        selectedRow = null;
        selectedCol = null;
      } else {
        selectedRow = row;
        selectedCol = col;
      }
    });
  }

  void _placeNumber(int number) {
    if (selectedRow == null || selectedCol == null) return;
    if (isFixed[selectedRow!][selectedCol!]) return;
    if (gameWon) return;

    setState(() {
      board[selectedRow!][selectedCol!] = number;
      if (solution[selectedRow!][selectedCol!] != number) mistakes++;
      if (_isPuzzleComplete()) {
        gameWon = true;
        _stopTimer();
        _showWinDialog();
        _submitGameResult();
      }
    });
  }

  void _eraseCell() {
    if (selectedRow == null || selectedCol == null) return;
    if (isFixed[selectedRow!][selectedCol!]) return;
    setState(() => board[selectedRow!][selectedCol!] = 0);
  }

  void _useHint() {
    if (selectedRow == null || selectedCol == null) return;
    if (isFixed[selectedRow!][selectedCol!]) return;
    if (gameWon) return;

    setState(() {
      board[selectedRow!][selectedCol!] = solution[selectedRow!][selectedCol!];
      hintsUsed++;
      if (_isPuzzleComplete()) {
        gameWon = true;
        _stopTimer();
        _showWinDialog();
        _submitGameResult();
      }
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

  // ── Submit result to backend ───────────────────────────────────────────────

  Future<void> _submitGameResult() async {
    final result = await GameService.submitResult(
      gameType:          'sudoku',
      score:             0,
      timePlayedSeconds: seconds,
      completed:         true,
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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber, size: 32),
            SizedBox(width: 12),
            Text('Congratulations!', style: TextStyle(fontSize: 24)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('You solved the puzzle!', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            SudokuStatRow(icon: Icons.timer,             label: 'Time',     value: _formatTime(seconds)),
            SudokuStatRow(icon: Icons.error_outline,     label: 'Mistakes', value: mistakes.toString()),
            SudokuStatRow(icon: Icons.lightbulb_outline, label: 'Hints',    value: hintsUsed.toString()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startNewGame();
            },
            child: const Text('New Game', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Sudoku',
          style: TextStyle(
            color: Color(0xFF6366F1),
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _startNewGame,
            icon: const Icon(Icons.refresh, color: Color(0xFF6366F1)),
            tooltip: 'New Game',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _BackButton(onTap: () => Navigator.pop(context)),
          // ── Top controls ────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SudokuInfoCard(icon: Icons.timer,         text: _formatTime(seconds)),
                SudokuDifficultySelector(
                  difficulty: difficulty,
                  onSelected: (value) {
                    setState(() => difficulty = value);
                    _startNewGame();
                  },
                ),
                SudokuInfoCard(icon: Icons.error_outline, text: mistakes.toString()),
              ],
            ),
          ),

          // ── Game board ──────────────────────────────────────────────────
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: FadeTransition(
                    opacity: _animationController,
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

          // ── Number pad ──────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SudokuNumberPad(
                  board:           board,
                  onNumberPressed: _placeNumber,
                ),
                const SizedBox(height: 12),
                SudokuActionButtons(
                  onHint:  _useHint,
                  onErase: _eraseCell,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


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
