import 'dart:math' as math;
import 'package:capstone_front_end/core/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../../core/constants/app_colors.dart';
import '../models/book_model.dart';
import '../models/book_snippet_model.dart';
import '../services/book_service.dart';
import '../../ai_flutter/widgets/snippet_check_sheet.dart';

class BookDetailPage extends StatefulWidget {
  final BookModel book;
  final bool audioMode;

  const BookDetailPage({Key? key, required this.book, this.audioMode = false}) : super(key: key);

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> with TickerProviderStateMixin {
  // ── Data ──────────────────────────────────────────────────────────────────
  List<BookSnippetModel> _snippets = [];
  bool _loading = true;
  String? _error;
  int _currentIndex = 0;

  // ── Modes ─────────────────────────────────────────────────────────────────
  bool _readingMode = false;
  bool _audioMode = false;

  // ── TTS ───────────────────────────────────────────────────────────────────
  final FlutterTts _tts = FlutterTts();
  bool _ttsPlaying = false;
  double _ttsProgress = 0.0;
  double _ttsSpeed = 1.0;
  final Set<int> _completedChapters = {};
  DateTime? _speakStartTime;

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _enterCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late PageController _pageController;

  // ── Waveform ───────────────────────────────────────────────────────────────
  static const int _waveBarCount = 28;
  final List<AnimationController> _barCtrls = [];
  final List<Animation<double>> _barAnims = [];

  @override
  void initState() {
    super.initState();
    _audioMode = widget.audioMode;

    _enterCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _pageController = PageController();
    _initWaveBars();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initTts();
    });
    _loadSnippets();
  }

  void _initWaveBars() {
    final rng = math.Random(42);
    for (int i = 0; i < _waveBarCount; i++) {
      final dur = Duration(milliseconds: 400 + rng.nextInt(600));
      final ctrl = AnimationController(vsync: this, duration: dur)..repeat(reverse: true);
      final anim = Tween<double>(begin: 0.15 + rng.nextDouble() * 0.25, end: 0.55 + rng.nextDouble() * 0.45).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeInOut));
      _barCtrls.add(ctrl);
      _barAnims.add(anim);
    }
    for (final c in _barCtrls) c.stop();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(_ttsSpeed);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setStartHandler(() {
      if (!mounted) return;
      _speakStartTime = DateTime.now();
      setState(() {
        _ttsPlaying = true;
        _ttsProgress = 0;
      });
      for (final c in _barCtrls) c.repeat(reverse: true);
      _startProgressTimer();
    });

    _tts.setCompletionHandler(() async {
      if (!mounted) return;
      final completedIdx = _currentIndex;
      final snippetId = _snippets[completedIdx].id;
      final token = await AuthService.getToken() ?? '';
      final passed = await showSnippetCheckSheet(context, snippetId: snippetId, token: token);
      if (passed) _completedChapters.add(completedIdx);
      setState(() {
        _ttsPlaying = false;
        _ttsProgress = 1.0;
      });
      for (final c in _barCtrls) c.stop();
      if (_currentIndex < _snippets.length - 1) {
        final next = _currentIndex + 1;
        Future.delayed(const Duration(milliseconds: 600), () {
          if (!mounted) return;
          setState(() {
            _currentIndex = next;
            _ttsProgress = 0;
          });
          _pageController.animateToPage(next, duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
          if (_audioMode) {
            Future.delayed(const Duration(milliseconds: 400), () {
              if (mounted) _ttsPlay();
            });
          }
        });
      }
    });

    _tts.setCancelHandler(() {
      if (mounted) setState(() => _ttsPlaying = false);
      for (final c in _barCtrls) c.stop();
    });

    _tts.setPauseHandler(() {
      if (mounted) setState(() => _ttsPlaying = false);
      for (final c in _barCtrls) c.stop();
    });

    _tts.setContinueHandler(() {
      if (mounted) setState(() => _ttsPlaying = true);
      for (final c in _barCtrls) c.repeat(reverse: true);
    });
  }

  void _startProgressTimer() {
    final snippet = _snippets.isNotEmpty ? _snippets[_currentIndex] : null;
    if (snippet == null) return;
    final wordCount = snippet.snippetText.split(' ').length;
    final estimatedSeconds = wordCount / (_ttsSpeed * 2.5);

    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted || !_ttsPlaying || _speakStartTime == null) return false;
      final elapsed = DateTime.now().difference(_speakStartTime!).inMilliseconds / 1000;
      final progress = (elapsed / estimatedSeconds).clamp(0.0, 0.98);
      if (mounted) setState(() => _ttsProgress = progress);
      return _ttsPlaying;
    });
  }

  @override
  void dispose() {
    _tts.stop();
    _enterCtrl.dispose();
    _pulseCtrl.dispose();
    _pageController.dispose();
    for (final c in _barCtrls) c.dispose();
    super.dispose();
  }

  Future<void> _loadSnippets() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snippets = await BookService.getSnippets(widget.book.id);
      final completedIndices = <int>{};
      for (int i = 0; i < snippets.length; i++) {
        if (snippets[i].isCompleted) completedIndices.add(i);
      }
      setState(() {
        _snippets = snippets;
        _completedChapters
          ..clear()
          ..addAll(completedIndices);
        _loading = false;
      });
      _enterCtrl.forward();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String get _currentText => _snippets.isNotEmpty ? _snippets[_currentIndex].snippetText : '';

  Future<void> _ttsPlay() async {
    if (_currentText.isEmpty || !mounted) return;
    try { _tts.stop(); } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    if (mounted) setState(() => _ttsProgress = 0);
    try { _tts.speak(_currentText); } catch (_) {}
  }

  Future<void> _ttsStop() async {
    if (mounted) setState(() { _ttsPlaying = false; _ttsProgress = 0; });
    for (final c in _barCtrls) c.stop();
    try { await _tts.stop(); } catch (_) {}
  }

  Future<void> _setSpeed(double speed) async {
    _ttsSpeed = speed;
    if (mounted) setState(() {});
    try { await _tts.setSpeechRate(speed); } catch (_) {}
    if (_ttsPlaying) await _ttsPlay();
  }

  BookSnippetModel? get _current => _snippets.isNotEmpty ? _snippets[_currentIndex] : null;

  Future<void> _goTo(int i, {bool autoPlay = false}) async {
    if (i < 0 || i >= _snippets.length || !mounted) return;
    try { _tts.stop(); } catch (_) {}
    if (!mounted) return;
    _speakStartTime = null;
    setState(() { _ttsPlaying = false; _ttsProgress = 0; _currentIndex = i; });
    for (final c in _barCtrls) c.stop();
    _pageController.animateToPage(i, duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    if (autoPlay && _audioMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) await _ttsPlay();
    }
  }

  Future<void> _markAndNext() async {
    if (_current == null) return;
    final completedIdx = _currentIndex;
    final snippetId = _current!.id;
    final token = await AuthService.getToken() ?? '';
    final passed = await showSnippetCheckSheet(context, snippetId: snippetId, token: token);
    if (passed) {
      _completedChapters.add(completedIdx);
      setState(() {});
    }
    if (_currentIndex < _snippets.length - 1) {
      _goTo(_currentIndex + 1);
    } else {
      _showCompletionSheet();
    }
  }

  void _showCompletionSheet() {
    try { _tts.stop(); } catch (_) {}
    if (mounted) setState(() => _ttsPlaying = false);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _CompletionSheet(book: widget.book),
    );
  }

  // Cover colors per book
  static const List<Color> _coverColors = [
    Color(0xFF2A9D8F),
    Color(0xFFF4A261),
    Color(0xFF9B5DE5),
    Color(0xFF2DC653),
    Color(0xFFF15BB5),
    Color(0xFFFEE440),
    Color(0xFFE63946),
    Color(0xFF0077B6),
  ];

  Color get _coverColor => _coverColors[widget.book.id % _coverColors.length];

  // ── Root build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_audioMode && _snippets.isNotEmpty) return _buildAudioPlayer();
    if (_readingMode && _snippets.isNotEmpty) return _buildReaderMode();
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: _loading
            ? _buildLoader()
            : _error != null
            ? _buildError()
            : FadeTransition(
                opacity: _enterCtrl,
                child: Column(
                  children: [
                    _buildTopBar(),
                    Expanded(child: _buildDetailContent()),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildLoader() => const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5));

  Widget _buildError() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline_rounded, color: AppColors.outlineVariant, size: 40),
        const SizedBox(height: 12),
        const Text('Failed to load', style: TextStyle(color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _loadSnippets,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
            child: const Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    ),
  );

  // ── Detail top bar ──────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('FocusPro', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Manrope')),
          ),
          if (_snippets.isNotEmpty) ...[
            GestureDetector(
              onTap: () => setState(() { _audioMode = true; _readingMode = false; }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.headphones_rounded, color: Colors.white, size: 15),
                    SizedBox(width: 5),
                    Text('Listen', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ── Detail content ──────────────────────────────────────────────────────────
  Widget _buildDetailContent() {
    final completedCount = _completedChapters.length;
    final totalCount = _snippets.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;
    final progressPercent = (progress * 100).toInt();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero: book cover + metadata
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Book Cover
                Container(
                  width: 120,
                  height: 180,
                  decoration: BoxDecoration(
                    color: _coverColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: _coverColor.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: Stack(
                    children: [
                      Center(child: Icon(Icons.menu_book_rounded, color: Colors.white.withOpacity(0.4), size: 48)),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              widget.book.title,
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // Title & metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        widget.book.title,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          fontFamily: 'Manrope',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.book.author,
                        style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _MetaChip(label: widget.book.levelLabel, color: AppColors.secondary),
                          _MetaChip(label: widget.book.category, color: AppColors.primary),
                          if (widget.book.totalPages != null)
                            _MetaChip(label: '${widget.book.totalPages} pages', color: const Color(0xFF0077B6)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Progress section
          if (_snippets.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CURRENT PROGRESS',
                                style: TextStyle(
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$progressPercent% Completed',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Manrope',
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_snippets.isNotEmpty)
                          GestureDetector(
                            onTap: () => setState(() { _readingMode = true; _audioMode = false; }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.primaryFixedDim,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.quiz_rounded, color: AppColors.onPrimaryFixedVariant, size: 14),
                                  SizedBox(width: 6),
                                  Text(
                                    'Test Your Retention',
                                    style: TextStyle(color: AppColors.onPrimaryFixedVariant, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: AppColors.surfaceContainerHigh,
                        valueColor: const AlwaysStoppedAnimation(AppColors.secondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          // About
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'About this book',
                  style: TextStyle(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(widget.book.description, style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13, height: 1.6)),
                ),
              ],
            ),
          ),
          // Chapter Roadmap
          if (_snippets.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Chapter Roadmap',
                    style: TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Manrope'),
                  ),
                  Text(
                    '${totalCount - completedCount} Remaining',
                    style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(_snippets.length, (i) {
              final s = _snippets[i];
              final done = _completedChapters.contains(i);
              final isCurrent = i == _currentIndex;

              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: GestureDetector(
                  onTap: () => setState(() { _currentIndex = i; _readingMode = true; }),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isCurrent && !done ? AppColors.primaryContainer : AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border(
                        left: BorderSide(
                          color: done ? AppColors.secondary : isCurrent ? AppColors.onTertiaryContainer : Colors.transparent,
                          width: 4,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: done
                                ? AppColors.secondaryContainer
                                : isCurrent
                                ? AppColors.onPrimaryContainer.withOpacity(0.2)
                                : AppColors.surfaceContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            done
                                ? Icons.check_circle_rounded
                                : isCurrent
                                ? Icons.play_circle_rounded
                                : Icons.lock_rounded,
                            color: done
                                ? AppColors.onSecondaryContainer
                                : isCurrent
                                ? Colors.white
                                : AppColors.onSurfaceVariant,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.snippetTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isCurrent && !done ? Colors.white : done ? AppColors.primary : AppColors.onSurface.withOpacity(done ? 0.6 : 1),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Manrope',
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                done ? 'Completed' : isCurrent ? 'Next up' : 'Locked',
                                style: TextStyle(
                                  color: isCurrent && !done ? AppColors.onPrimaryContainer : AppColors.onSurfaceVariant,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isCurrent && !done ? Icons.auto_awesome_rounded : Icons.chevron_right_rounded,
                          color: isCurrent && !done ? Colors.white : AppColors.outlineVariant.withOpacity(0.5),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  AUDIO PLAYER SCREEN  (TTS Audio Player design)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildAudioPlayer() {
    const bgColor = Color(0xFF171717); // neutral-900
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildAudioTopBar(bgColor),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      _buildAudioCoverArt(),
                      const SizedBox(height: 24),
                      _buildAudioTitleInfo(),
                      const SizedBox(height: 28),
                      _buildTtsProgressBar(),
                      const SizedBox(height: 24),
                      _buildSpeedSelector(),
                      const SizedBox(height: 28),
                      _buildAudioMainControls(),
                      const SizedBox(height: 32),
                      _buildAudioChapterList(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioTopBar(Color bgColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              await _ttsStop();
              if (mounted) setState(() => _audioMode = false);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF9CA3AF), size: 20),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'NOW LISTENING',
                  style: TextStyle(
                    color: AppColors.secondaryFixed.withOpacity(0.7),
                    fontSize: 9,
                    letterSpacing: 2.5,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Manrope',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Chapter ${_currentIndex + 1} of ${_snippets.length}',
                  style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Manrope'),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              await _ttsStop();
              if (mounted) setState(() { _audioMode = false; _readingMode = true; });
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.menu_book_rounded, color: Color(0xFF9CA3AF), size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioCoverArt() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, __) => Transform.scale(
        scale: _ttsPlaying ? _pulseAnim.value : 1.0,
        child: Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppColors.secondary.withOpacity(0.4), Colors.transparent],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.secondaryFixed.withOpacity(_ttsPlaying ? 0.2 : 0.08),
                blurRadius: _ttsPlaying ? 80 : 40,
                spreadRadius: _ttsPlaying ? 10 : 2,
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _coverColor,
              border: Border.all(color: const Color(0xFF171717), width: 4),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.menu_book_rounded, color: Colors.white.withOpacity(0.3), size: 72),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAudioTitleInfo() {
    return Column(
      children: [
        Text(
          _snippets.isNotEmpty ? _snippets[_currentIndex].snippetTitle : widget.book.title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, height: 1.3, fontFamily: 'Manrope'),
        ),
        const SizedBox(height: 8),
        Text(widget.book.author, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 15, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildTtsProgressBar() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: _ttsProgress,
            minHeight: 6,
            backgroundColor: const Color(0xFF374151),
            valueColor: const AlwaysStoppedAnimation(AppColors.secondaryFixed),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${(_ttsProgress * 12).toStringAsFixed(0)}:00', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
            Text('12:00', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
          ],
        ),
      ],
    );
  }

  Widget _buildSpeedSelector() {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: speeds.map((s) {
        final selected = (_ttsSpeed - s).abs() < 0.01;
        return GestureDetector(
          onTap: () => _setSpeed(s),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? AppColors.secondaryFixed : const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(20),
              boxShadow: selected
                  ? [BoxShadow(color: AppColors.secondaryFixed.withOpacity(0.2), blurRadius: 12)]
                  : [],
            ),
            child: Text(
              s == s.roundToDouble() ? '${s.toInt()}x' : '${s}x',
              style: TextStyle(
                color: selected ? AppColors.primary : const Color(0xFF9CA3AF),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAudioMainControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _AudioBtn(
          icon: Icons.skip_previous_rounded,
          size: 28,
          color: _currentIndex > 0 ? const Color(0xFF9CA3AF) : const Color(0xFF374151),
          onTap: _currentIndex > 0 ? () => _goTo(_currentIndex - 1, autoPlay: _ttsPlaying) : null,
        ),
        _AudioBtn(
          icon: Icons.replay_10_rounded,
          size: 26,
          color: const Color(0xFF9CA3AF),
          onTap: () => _ttsPlay(),
        ),
        GestureDetector(
          onTap: _ttsPlaying ? _ttsStop : _ttsPlay,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.secondaryFixed,
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondaryFixed.withOpacity(_ttsPlaying ? 0.3 : 0.15),
                  blurRadius: _ttsPlaying ? 30 : 16,
                  spreadRadius: _ttsPlaying ? 4 : 1,
                ),
              ],
            ),
            child: Icon(
              _ttsPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: AppColors.primary,
              size: 44,
            ),
          ),
        ),
        _AudioBtn(
          icon: Icons.forward_10_rounded,
          size: 26,
          color: const Color(0xFF9CA3AF),
          onTap: () {},
        ),
        _AudioBtn(
          icon: Icons.skip_next_rounded,
          size: 28,
          color: _currentIndex < _snippets.length - 1 ? const Color(0xFF9CA3AF) : const Color(0xFF374151),
          onTap: _currentIndex < _snippets.length - 1 ? () => _goTo(_currentIndex + 1, autoPlay: _ttsPlaying) : null,
        ),
      ],
    );
  }

  Widget _buildAudioChapterList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Chapters', style: TextStyle(color: Color(0xFFE5E7EB), fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Manrope')),
            const Spacer(),
            Text(
              '${_completedChapters.length} OF ${_snippets.length} COMPLETED',
              style: TextStyle(color: AppColors.secondaryFixed.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...List.generate(_snippets.length, (i) {
          final s = _snippets[i];
          final active = i == _currentIndex;
          final done = _completedChapters.contains(i);
          return GestureDetector(
            onTap: () => _goTo(i, autoPlay: _ttsPlaying),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: active ? AppColors.primaryContainer.withOpacity(0.3) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: active ? AppColors.secondaryFixed.withOpacity(0.15) : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done
                          ? AppColors.secondaryFixed.withOpacity(0.2)
                          : active
                          ? AppColors.secondaryFixed.withOpacity(0.1)
                          : const Color(0xFF1F2937),
                    ),
                    child: done
                        ? const Icon(Icons.check_circle_rounded, color: AppColors.secondaryFixed, size: 18)
                        : active
                        ? const Icon(Icons.equalizer_rounded, color: AppColors.secondaryFixed, size: 18)
                        : Center(child: Text('${i + 1}', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11, fontWeight: FontWeight.bold))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.snippetTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: active ? Colors.white : const Color(0xFFD1D5DB),
                            fontSize: 13,
                            fontWeight: active ? FontWeight.bold : FontWeight.normal,
                            fontFamily: 'Manrope',
                          ),
                        ),
                        if (s.durationSeconds != null)
                          Text('${s.durationLabel}', style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.play_circle_rounded,
                    color: active ? AppColors.secondaryFixed : const Color(0xFF374151),
                    size: 20,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  TEXT READER SCREEN  (Book Text Reader design)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildReaderMode() {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            _buildReaderTopBar(),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _snippets.length,
                onPageChanged: (i) => setState(() => _currentIndex = i),
                itemBuilder: (_, i) => _ReaderPage(snippet: _snippets[i]),
              ),
            ),
            _buildReaderControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildReaderTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: AppColors.primary.withOpacity(0.8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() => _readingMode = false),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                const Text(
                  'Now Reading',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Manrope'),
                ),
                Text(
                  'Chapter ${_currentIndex + 1} of ${_snippets.length}',
                  style: TextStyle(color: AppColors.onPrimaryContainer.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.5),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() { _readingMode = false; _audioMode = true; }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.headphones_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 5),
                  Text('Listen', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReaderControls() {
    return Container(
      color: AppColors.primary,
      child: Column(
        children: [
          // "Done & Next" button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: GestureDetector(
              onTap: _markAndNext,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 30, spreadRadius: -5)],
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        _currentIndex < _snippets.length - 1 ? 'Done & Next' : 'Complete Book',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Manrope'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Bottom nav bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08)))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavBtn(icon: Icons.menu_book_rounded, label: 'Chapter', active: true, onTap: () {}),
                _NavBtn(icon: Icons.format_size_rounded, label: 'Text Size', active: false, onTap: () {}),
                _NavBtn(icon: Icons.bookmark_rounded, label: 'Bookmark', active: false, onTap: () {}),
                _NavBtn(icon: Icons.settings_rounded, label: 'Settings', active: false, onTap: () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _ReaderPage — single snippet page (dark green background)
// ═════════════════════════════════════════════════════════════════════════════
class _ReaderPage extends StatelessWidget {
  final BookSnippetModel snippet;
  const _ReaderPage({required this.snippet});

  List<String> get _paragraphs => snippet.snippetText.split(RegExp(r'\n+')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Deep Work',
                        style: TextStyle(
                          color: AppColors.tertiaryFixedDim,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                          fontFamily: 'Manrope',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        snippet.snippetTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          fontFamily: 'Manrope',
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(width: 48, height: 4, decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(2))),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                ..._paragraphs.asMap().entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Text(
                      e.value,
                      textAlign: TextAlign.left,
                      style: const TextStyle(
                        color: AppColors.onPrimaryContainer,
                        fontSize: 17,
                        height: 1.85,
                        letterSpacing: 0.1,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.primaryContainer, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.primaryContainer.withOpacity(0.5), shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.primaryContainer.withOpacity(0.2), shape: BoxShape.circle)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Shared helper widgets
// ═════════════════════════════════════════════════════════════════════════════

class _AudioBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final VoidCallback? onTap;
  const _AudioBtn({required this.icon, required this.size, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(onTap != null ? 0.05 : 0.02)),
      child: Icon(icon, color: color, size: size),
    ),
  );
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: active
          ? BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(12))
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: active ? Colors.white : AppColors.onPrimaryContainer, size: 22),
        ],
      ),
    ),
  );
}

class _MetaChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MetaChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}

class _CompletionSheet extends StatelessWidget {
  final BookModel book;
  const _CompletionSheet({required this.book});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.1), blurRadius: 40, spreadRadius: 4)],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(color: AppColors.primaryContainer, shape: BoxShape.circle),
          child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 16),
        const Text('Book Completed!', style: TextStyle(color: AppColors.onSurface, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Manrope')),
        const SizedBox(height: 8),
        Text(
          'You finished "${book.title}". Great job keeping your focus!',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () { Navigator.pop(context); Navigator.pop(context); },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(14)),
            child: const Center(child: Text('Back to Library', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
          ),
        ),
      ],
    ),
  );
}
