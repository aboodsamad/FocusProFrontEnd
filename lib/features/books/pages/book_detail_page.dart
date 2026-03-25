import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../../core/constants/app_colors.dart';
import '../models/book_model.dart';
import '../models/book_snippet_model.dart';
import '../services/book_service.dart';

class BookDetailPage extends StatefulWidget {
  final BookModel book;

  /// If true, opens directly in the TTS audio player mode
  final bool audioMode;

  const BookDetailPage({
    Key? key,
    required this.book,
    this.audioMode = false,
  }) : super(key: key);

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage>
    with TickerProviderStateMixin {
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
  final Set<int> _completedChapters = {}; // tracks actually-read chapters
  DateTime? _speakStartTime;             // used to animate progress bar

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

    _enterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _pageController = PageController();
    _initWaveBars();
    // Use post-frame so _initTts (async) runs after first build
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initTts();
    });
    _loadSnippets();
  }

  void _initWaveBars() {
    final rng = math.Random(42);
    for (int i = 0; i < _waveBarCount; i++) {
      final dur = Duration(milliseconds: 400 + rng.nextInt(600));
      final ctrl = AnimationController(vsync: this, duration: dur)
        ..repeat(reverse: true);
      final anim = Tween<double>(
              begin: 0.15 + rng.nextDouble() * 0.25,
              end: 0.55 + rng.nextDouble() * 0.45)
          .animate(CurvedAnimation(parent: ctrl, curve: Curves.easeInOut));
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
      setState(() { _ttsPlaying = true; _ttsProgress = 0; });
      for (final c in _barCtrls) c.repeat(reverse: true);
      _startProgressTimer();
    });

    _tts.setCompletionHandler(() {
      if (!mounted) return;
      // Mark this chapter as genuinely completed
      _completedChapters.add(_currentIndex);
      setState(() { _ttsPlaying = false; _ttsProgress = 1.0; });
      for (final c in _barCtrls) c.stop();
      // Auto-advance without calling stop() — engine already finished
      if (_currentIndex < _snippets.length - 1) {
        final next = _currentIndex + 1;
        Future.delayed(const Duration(milliseconds: 600), () {
          if (!mounted) return;
          setState(() { _currentIndex = next; _ttsProgress = 0; });
          _pageController.animateToPage(next,
              duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
          if (_audioMode) {
            Future.delayed(const Duration(milliseconds: 400), () {
              if (mounted) _ttsPlay();
            });
          }
        });
      }
    });

    _tts.setCancelHandler(() {
      if (mounted) setState(() { _ttsPlaying = false; });
      for (final c in _barCtrls) c.stop();
    });

    _tts.setPauseHandler(() {
      if (mounted) setState(() { _ttsPlaying = false; });
      for (final c in _barCtrls) c.stop();
    });

    _tts.setContinueHandler(() {
      if (mounted) setState(() { _ttsPlaying = true; });
      for (final c in _barCtrls) c.repeat(reverse: true);
    });
  }

  // Timer-based progress: estimates position from elapsed time vs word count
  void _startProgressTimer() {
    final snippet = _snippets.isNotEmpty ? _snippets[_currentIndex] : null;
    if (snippet == null) return;
    // Estimate total duration: words / (speed * 2.5 words-per-second)
    final wordCount = snippet.snippetText.split(' ').length;
    final estimatedSeconds = wordCount / (_ttsSpeed * 2.5);

    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted || !_ttsPlaying || _speakStartTime == null) return false;
      final elapsed = DateTime.now().difference(_speakStartTime!).inMilliseconds / 1000;
      final progress = (elapsed / estimatedSeconds).clamp(0.0, 0.98);
      if (mounted) setState(() => _ttsProgress = progress);
      return _ttsPlaying; // keep looping while playing
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

  // ── Data loading ───────────────────────────────────────────────────────────
  Future<void> _loadSnippets() async {
    setState(() { _loading = true; _error = null; });
    try {
      final snippets = await BookService.getSnippets(widget.book.id);
      setState(() { _snippets = snippets; _loading = false; });
      _enterCtrl.forward();
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── TTS controls ───────────────────────────────────────────────────────────
  String get _currentText =>
      _snippets.isNotEmpty ? _snippets[_currentIndex].snippetText : '';

  // RULE: always stop first (fire-and-forget), wait, then speak.
  // Never lock, never await speak() — on web it never resolves while playing.
  Future<void> _ttsPlay() async {
    if (_currentText.isEmpty || !mounted) return;
    try { _tts.stop(); } catch (_) {}               // fire-and-forget stop
    await Future.delayed(const Duration(milliseconds: 300)); // let browser settle
    if (!mounted) return;
    if (mounted) setState(() { _ttsProgress = 0; });
    try { _tts.speak(_currentText); } catch (_) {}  // fire-and-forget speak
  }

  // Stop is always unconditional — never check _ttsPlaying first
  Future<void> _ttsStop() async {
    if (mounted) setState(() { _ttsPlaying = false; _ttsProgress = 0; });
    for (final c in _barCtrls) c.stop();
    try { await _tts.stop(); } catch (_) {}
  }

  Future<void> _setSpeed(double speed) async {
    _ttsSpeed = speed;
    if (mounted) setState(() {});
    try { await _tts.setSpeechRate(speed); } catch (_) {}
    // If currently playing, restart at new speed
    if (_ttsPlaying) await _ttsPlay();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  BookSnippetModel? get _current =>
      _snippets.isNotEmpty ? _snippets[_currentIndex] : null;

  Future<void> _goTo(int i, {bool autoPlay = false}) async {
    if (i < 0 || i >= _snippets.length || !mounted) return;
    // Stop unconditionally — don't check _ttsPlaying, it may be stale
    try { _tts.stop(); } catch (_) {}
    if (!mounted) return;
    _speakStartTime = null;
    setState(() { _ttsPlaying = false; _ttsProgress = 0; _currentIndex = i; });
    for (final c in _barCtrls) c.stop();
    _pageController.animateToPage(i,
        duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    if (autoPlay && _audioMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) await _ttsPlay();
    }
  }

  Future<void> _markAndNext() async {
    if (_current == null) return;
    try { await BookService.markSnippetComplete(_current!.id); } catch (_) {}
    if (_currentIndex < _snippets.length - 1) {
      _goTo(_currentIndex + 1);
    } else {
      _showCompletionSheet();
    }
  }

  void _showCompletionSheet() {
    try { _tts.stop(); } catch (_) {}
    if (mounted) setState(() { _ttsPlaying = false; });
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => _CompletionSheet(book: widget.book),
    );
  }

  // ── Palette helpers ────────────────────────────────────────────────────────
  static const List<List<Color>> _palettes = [
    [Color(0xFF667eea), Color(0xFF764ba2)],
    [Color(0xFF10B981), Color(0xFF065F46)],
    [Color(0xFFF97316), Color(0xFF9A3412)],
    [Color(0xFFEC4899), Color(0xFF831843)],
    [Color(0xFF06B6D4), Color(0xFF164E63)],
    [Color(0xFF8B5CF6), Color(0xFF3B0764)],
    [Color(0xFFEAB308), Color(0xFF713F12)],
    [Color(0xFF14B8A6), Color(0xFF134E4A)],
  ];
  List<Color> get _palette => _palettes[widget.book.id % _palettes.length];

  Color get _levelColor {
    switch (widget.book.level) {
      case 1: return const Color(0xFF10B981);
      case 2: return const Color(0xFFF97316);
      case 3: return const Color(0xFFEF4444);
      default: return AppColors.primaryA;
    }
  }

  // ── Root build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_audioMode && _snippets.isNotEmpty) return _buildAudioPlayer();
    if (_readingMode && _snippets.isNotEmpty) return _buildReaderMode();
    return Scaffold(
      backgroundColor: const Color(0xFF080D1A),
      body: SafeArea(
        child: _loading
            ? _buildLoader()
            : _error != null
                ? _buildError()
                : FadeTransition(
                    opacity: _enterCtrl,
                    child: Column(children: [
                      _buildTopBar(),
                      Expanded(child: _buildDetailContent()),
                    ])),
      ),
    );
  }

  Widget _buildLoader() => const Center(
      child: CircularProgressIndicator(color: AppColors.primaryA, strokeWidth: 2.5));

  Widget _buildError() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.error_outline_rounded, color: Colors.grey[600], size: 40),
      const SizedBox(height: 12),
      Text('Failed to load', style: TextStyle(color: Colors.grey[500])),
      const SizedBox(height: 16),
      GestureDetector(
        onTap: _loadSnippets,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.primaryA, AppColors.primaryB]),
            borderRadius: BorderRadius.circular(10)),
          child: const Text('Retry',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    ]),
  );

  // ── Detail screen top bar ──────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.08))),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white70, size: 16)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(widget.book.title,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white,
                  fontSize: 16, fontWeight: FontWeight.bold))),
        if (_snippets.isNotEmpty) ...[
          // 🎧 Audio
          GestureDetector(
            onTap: () => setState(() { _audioMode = true; _readingMode = false; }),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEC4899).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEC4899).withOpacity(0.3))),
              child: const Icon(Icons.headphones_rounded,
                  color: Color(0xFFEC4899), size: 18)),
          ),
          const SizedBox(width: 8),
          // 📖 Read
          GestureDetector(
            onTap: () => setState(() { _readingMode = true; _audioMode = false; }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primaryA, AppColors.primaryB]),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(
                    color: AppColors.primaryA.withOpacity(0.4), blurRadius: 12)]),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text('Read', style: TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ])),
          ),
        ],
      ]),
    );
  }

  // ── Detail content ─────────────────────────────────────────────────────────
  Widget _buildDetailContent() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildCoverHero(),
        const SizedBox(height: 24),
        _buildMeta(),
        const SizedBox(height: 20),
        _buildDescription(),
        if (_snippets.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildProgressSection(),
          const SizedBox(height: 24),
          _buildSnippetList(),
        ],
      ]),
    );
  }

  Widget _buildCoverHero() {
    return Center(
      child: Container(
        width: 140, height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(colors: _palette,
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [BoxShadow(color: _palette[0].withOpacity(0.5),
              blurRadius: 40, offset: const Offset(0, 16))]),
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _CoverPainter(widget.book.id))),
          Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.menu_book_rounded, color: Colors.white54, size: 48),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(widget.book.title,
                  textAlign: TextAlign.center, maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white,
                      fontSize: 11, fontWeight: FontWeight.bold, height: 1.3))),
          ])),
        ]),
      ),
    );
  }

  Widget _buildMeta() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.book.title,
          style: const TextStyle(color: Colors.white,
              fontSize: 22, fontWeight: FontWeight.bold, height: 1.2)),
      const SizedBox(height: 6),
      Text('by ${widget.book.author}',
          style: TextStyle(color: Colors.grey[400], fontSize: 14)),
      const SizedBox(height: 14),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _MetaChip(icon: Icons.signal_cellular_alt_rounded,
            label: widget.book.levelLabel, color: _levelColor),
        _MetaChip(icon: Icons.category_rounded,
            label: widget.book.category, color: AppColors.primaryA),
        if (widget.book.totalPages != null)
          _MetaChip(icon: Icons.auto_stories_rounded,
              label: '${widget.book.totalPages} pages',
              color: const Color(0xFF06B6D4)),
        if (_snippets.isNotEmpty)
          _MetaChip(icon: Icons.layers_rounded,
              label: '${_snippets.length} chapters',
              color: const Color(0xFF10B981)),
      ]),
    ]);
  }

  Widget _buildDescription() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('About this book',
          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1624),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06))),
        child: Text(widget.book.description,
            style: TextStyle(color: Colors.grey[300], fontSize: 13, height: 1.6))),
    ]);
  }

  Widget _buildProgressSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.primaryB.withOpacity(0.3),
          AppColors.primaryA.withOpacity(0.12)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryA.withOpacity(0.2))),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Row(children: [
            Icon(Icons.track_changes_rounded, color: AppColors.primaryA, size: 16),
            SizedBox(width: 8),
            Text('Your progress', style: TextStyle(color: Colors.white,
                fontWeight: FontWeight.bold, fontSize: 13)),
          ]),
          Text('${_completedChapters.length} / ${_snippets.length} chapters',
              style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: _completedChapters.length / math.max(_snippets.length, 1),
            minHeight: 6,
            backgroundColor: Colors.white.withOpacity(0.07),
            valueColor: const AlwaysStoppedAnimation(AppColors.primaryA))),
      ]),
    );
  }

  Widget _buildSnippetList() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Chapters', style: TextStyle(color: Colors.white,
          fontSize: 15, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      ...List.generate(_snippets.length, (i) {
        final s = _snippets[i];
        return _SnippetListTile(
          snippet: s, index: i,
          isRead: _completedChapters.contains(i), isCurrent: i == _currentIndex,
          onTap: () => setState(() { _currentIndex = i; _readingMode = true; }),
          onAudioTap: () => setState(() {
            _currentIndex = i; _audioMode = true; _readingMode = false;
          }),
        );
      }),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  AUDIO PLAYER SCREEN
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildAudioPlayer() {
    return Scaffold(
      backgroundColor: const Color(0xFF060A14),
      body: SafeArea(
        child: Column(children: [
          _buildAudioTopBar(),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(children: [
                const SizedBox(height: 32),
                _buildAudioCoverArt(),
                const SizedBox(height: 28),
                _buildAudioTitleInfo(),
                const SizedBox(height: 32),
                _buildWaveform(),
                const SizedBox(height: 20),
                _buildTtsProgressBar(),
                const SizedBox(height: 28),
                _buildSpeedSelector(),
                const SizedBox(height: 28),
                _buildAudioMainControls(),
                const SizedBox(height: 32),
                _buildAudioChapterList(),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildAudioTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(children: [
        // Collapse
        GestureDetector(
          onTap: () async { await _ttsStop(); if (mounted) setState(() { _audioMode = false; }); },
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: Colors.white.withOpacity(0.06))),
            child: const Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.white60, size: 22)),
        ),
        const Spacer(),
        Column(children: [
          const Text('NOW LISTENING', style: TextStyle(color: Color(0xFFEC4899),
              fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text('Chapter ${_currentIndex + 1} of ${_snippets.length}',
              style: TextStyle(color: Colors.grey[600], fontSize: 11)),
        ]),
        const Spacer(),
        // Switch to text reader
        GestureDetector(
          onTap: () async { await _ttsStop(); if (mounted) setState(() { _audioMode = false; _readingMode = true; }); },
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: Colors.white.withOpacity(0.06))),
            child: const Icon(Icons.menu_book_rounded,
                color: Colors.white60, size: 17)),
        ),
      ]),
    );
  }

  Widget _buildAudioCoverArt() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, __) => Transform.scale(
        scale: _ttsPlaying ? _pulseAnim.value : 1.0,
        child: Container(
          width: 210, height: 210,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              _palette[0].withOpacity(0.9), _palette[1].withOpacity(0.7),
            ]),
            boxShadow: [BoxShadow(
              color: _palette[0].withOpacity(_ttsPlaying ? 0.55 : 0.22),
              blurRadius: _ttsPlaying ? 70 : 30,
              spreadRadius: _ttsPlaying ? 14 : 4)]),
          child: Stack(alignment: Alignment.center, children: [
            CustomPaint(
                painter: _CoverPainter(widget.book.id),
                size: const Size(210, 210)),
            const Icon(Icons.menu_book_rounded, color: Colors.white54, size: 68),
          ])),
      ),
    );
  }

  Widget _buildAudioTitleInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(children: [
        Text(
          _snippets.isNotEmpty
              ? _snippets[_currentIndex].snippetTitle
              : widget.book.title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white,
              fontSize: 20, fontWeight: FontWeight.bold, height: 1.3)),
        const SizedBox(height: 8),
        Text(widget.book.author,
            style: TextStyle(color: Colors.grey[500], fontSize: 14)),
      ]),
    );
  }

  Widget _buildWaveform() {
    return SizedBox(
      height: 52,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(_waveBarCount, (i) {
          return AnimatedBuilder(
            animation: _barAnims[i],
            builder: (_, __) {
              final h = _ttsPlaying ? 8 + _barAnims[i].value * 44 : 6.0;
              final center = (i - _waveBarCount ~/ 2).abs() < _waveBarCount ~/ 5;
              return Container(
                width: 3, height: h,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: LinearGradient(
                    colors: _ttsPlaying
                        ? [_palette[0], _palette[1]]
                        : [Colors.white.withOpacity(center ? 0.15 : 0.07),
                           Colors.white.withOpacity(0.04)],
                    begin: Alignment.topCenter, end: Alignment.bottomCenter)));
            },
          );
        }),
      ),
    );
  }

  Widget _buildTtsProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _ttsProgress,
            minHeight: 3,
            backgroundColor: Colors.white.withOpacity(0.07),
            valueColor: AlwaysStoppedAnimation(_palette[0]))),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Chapter ${_currentIndex + 1}',
              style: TextStyle(color: Colors.grey[700], fontSize: 11)),
          Text('${(_ttsProgress * 100).toInt()}%',
              style: TextStyle(color: Colors.grey[700], fontSize: 11)),
        ]),
      ]),
    );
  }

  Widget _buildSpeedSelector() {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: speeds.map((s) {
        final selected = (_ttsSpeed - s).abs() < 0.01;
        return GestureDetector(
          onTap: () => _setSpeed(s),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: selected ? _palette[0].withOpacity(0.2) : Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? _palette[0].withOpacity(0.6) : Colors.white.withOpacity(0.06))),
            child: Text(
              s == s.roundToDouble() ? '${s.toInt()}x' : '${s}x',
              style: TextStyle(
                color: selected ? _palette[0] : Colors.grey[600],
                fontSize: 11, fontWeight: FontWeight.bold))),
        );
      }).toList(),
    );
  }

  Widget _buildAudioMainControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        // Previous
        _AudioBtn(
          icon: Icons.skip_previous_rounded, size: 28,
          color: _currentIndex > 0 ? Colors.white70 : Colors.white24,
          onTap: _currentIndex > 0
              ? () => _goTo(_currentIndex - 1, autoPlay: _ttsPlaying) : null),
        // Replay
        _AudioBtn(
          icon: Icons.replay_rounded, size: 24, color: Colors.white60,
          onTap: () => _ttsPlay()),
        // Play / Pause — big center button
        GestureDetector(
          onTap: _ttsPlaying ? _ttsStop : _ttsPlay,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: _palette),
              boxShadow: [BoxShadow(
                color: _palette[0].withOpacity(_ttsPlaying ? 0.55 : 0.3),
                blurRadius: _ttsPlaying ? 30 : 16,
                spreadRadius: _ttsPlaying ? 4 : 1)]),
            child: Icon(
              _ttsPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white, size: 36))),
        // Stop
        _AudioBtn(
          icon: Icons.stop_rounded, size: 24,
          color: _ttsPlaying ? Colors.white60 : Colors.white24,
          onTap: _ttsPlaying ? _ttsStop : null),
        // Next
        _AudioBtn(
          icon: Icons.skip_next_rounded, size: 28,
          color: _currentIndex < _snippets.length - 1 ? Colors.white70 : Colors.white24,
          onTap: _currentIndex < _snippets.length - 1
              ? () => _goTo(_currentIndex + 1, autoPlay: _ttsPlaying) : null),
      ]),
    );
  }

  Widget _buildAudioChapterList() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(children: [
          const Text('Chapters', style: TextStyle(color: Colors.white,
              fontSize: 14, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('${_snippets.length} total',
              style: TextStyle(color: Colors.grey[600], fontSize: 11)),
        ]),
      ),
      const SizedBox(height: 12),
      ...List.generate(_snippets.length, (i) {
        final s = _snippets[i];
        final active = i == _currentIndex;
        final done = _completedChapters.contains(i);
        return GestureDetector(
          onTap: () => _goTo(i, autoPlay: _ttsPlaying),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: active ? _palette[0].withOpacity(0.12) : Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? _palette[0].withOpacity(0.4) : Colors.white.withOpacity(0.04))),
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? const Color(0xFF10B981).withOpacity(0.15)
                      : active ? _palette[0].withOpacity(0.2) : Colors.white.withOpacity(0.03)),
                child: Icon(
                  done ? Icons.check_rounded
                      : active ? Icons.graphic_eq_rounded
                          : Icons.radio_button_unchecked_rounded,
                  size: 14,
                  color: done ? const Color(0xFF10B981)
                      : active ? _palette[0] : Colors.grey[700])),
              const SizedBox(width: 12),
              Expanded(
                child: Text(s.snippetTitle,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: active ? Colors.white : Colors.grey[500],
                        fontSize: 13,
                        fontWeight: active ? FontWeight.bold : FontWeight.normal))),
              if (s.durationSeconds != null)
                Text(s.durationLabel,
                    style: TextStyle(color: Colors.grey[700], fontSize: 10)),
            ])),
        );
      }),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  TEXT READER SCREEN
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildReaderMode() {
    return Scaffold(
      backgroundColor: const Color(0xFF060A14),
      body: SafeArea(
        child: Column(children: [
          _buildReaderTopBar(),
          _buildReaderProgress(),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _snippets.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (_, i) => _ReaderPage(snippet: _snippets[i]))),
          _buildReaderControls(),
        ]),
      ),
    );
  }

  Widget _buildReaderTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(children: [
        GestureDetector(
          onTap: () => setState(() => _readingMode = false),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: Colors.white.withOpacity(0.06))),
            child: const Icon(Icons.close_rounded, color: Colors.white60, size: 18)),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.book.title,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70,
                  fontSize: 13, fontWeight: FontWeight.bold)),
          Text('Chapter ${_currentIndex + 1} of ${_snippets.length}',
              style: TextStyle(color: Colors.grey[700], fontSize: 11)),
        ])),
        // Switch to audio
        GestureDetector(
          onTap: () => setState(() { _readingMode = false; _audioMode = true; }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEC4899).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEC4899).withOpacity(0.3))),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.headphones_rounded, color: Color(0xFFEC4899), size: 14),
              SizedBox(width: 5),
              Text('Listen', style: TextStyle(color: Color(0xFFEC4899),
                  fontSize: 11, fontWeight: FontWeight.bold)),
            ])),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primaryA.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primaryA.withOpacity(0.3))),
          child: Text(
            _current?.pageNumber != null
                ? 'p.${_current!.pageNumber}'
                : '${_currentIndex + 1}/${_snippets.length}',
            style: const TextStyle(color: AppColors.primaryA,
                fontSize: 11, fontWeight: FontWeight.bold))),
      ]),
    );
  }

  Widget _buildReaderProgress() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: List.generate(_snippets.length, (i) {
          final done = _completedChapters.contains(i);
          final active = i == _currentIndex;
          return Expanded(
            child: Container(
              height: 3,
              margin: EdgeInsets.only(right: i < _snippets.length - 1 ? 2 : 0),
              decoration: BoxDecoration(
                color: done
                    ? AppColors.primaryA
                    : active
                        ? AppColors.primaryA.withOpacity(0.5)
                        : Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(2))));
        }),
      ),
    );
  }

  Widget _buildReaderControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Row(children: [
        GestureDetector(
          onTap: _currentIndex > 0 ? () => _goTo(_currentIndex - 1) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: _currentIndex > 0
                  ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(
                  _currentIndex > 0 ? 0.1 : 0.04))),
            child: Icon(Icons.arrow_back_rounded,
                color: _currentIndex > 0 ? Colors.white60 : Colors.white12,
                size: 20)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: _markAndNext,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.primaryA, AppColors.primaryB]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: AppColors.primaryA.withOpacity(0.4),
                    blurRadius: 16, spreadRadius: 1)]),
              child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  _currentIndex < _snippets.length - 1
                      ? Icons.check_rounded : Icons.emoji_events_rounded,
                  color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  _currentIndex < _snippets.length - 1
                      ? 'Done & Next' : 'Complete Book',
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 15)),
              ])))),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _currentIndex < _snippets.length - 1
              ? () => _goTo(_currentIndex + 1) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: _currentIndex < _snippets.length - 1
                  ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(
                  _currentIndex < _snippets.length - 1 ? 0.1 : 0.04))),
            child: Icon(Icons.arrow_forward_rounded,
                color: _currentIndex < _snippets.length - 1
                    ? Colors.white60 : Colors.white12,
                size: 20)),
        ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _ReaderPage  — single snippet rendered as a book page
// ═════════════════════════════════════════════════════════════════════════════
class _ReaderPage extends StatelessWidget {
  final BookSnippetModel snippet;
  const _ReaderPage({required this.snippet});

  List<String> get _paragraphs => snippet.snippetText
      .split(RegExp(r'\n+'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();

  @override
  Widget build(BuildContext context) {
    final maxWidth =
        MediaQuery.of(context).size.width > 680 ? 640.0 : double.infinity;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 48),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Column(children: [
                Text(
                  '— ${snippet.sequenceOrder != null ? 'Chapter ${snippet.sequenceOrder}' : '§'} —',
                  style: TextStyle(color: AppColors.primaryA.withOpacity(0.6),
                      fontSize: 11, letterSpacing: 3, fontWeight: FontWeight.w500)),
                const SizedBox(height: 16),
                Text(snippet.snippetTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white,
                        fontSize: 22, fontWeight: FontWeight.w700,
                        height: 1.3, letterSpacing: -0.3)),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(width: 40, height: 1,
                      color: AppColors.primaryA.withOpacity(0.3)),
                  Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                          color: AppColors.primaryA.withOpacity(0.5),
                          shape: BoxShape.circle)),
                  Container(width: 40, height: 1,
                      color: AppColors.primaryA.withOpacity(0.3)),
                ]),
              ])),
              const SizedBox(height: 32),
              ..._paragraphs.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  e.key == 0 ? e.value : '    ${e.value}',
                  textAlign: TextAlign.justify,
                  style: const TextStyle(
                      color: Color(0xFFCDD5E0),
                      fontSize: 17, height: 1.95,
                      letterSpacing: 0.15, fontWeight: FontWeight.w400)))),
              const SizedBox(height: 8),
              Center(child: Row(mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                Container(width: 24, height: 1, color: Colors.white.withOpacity(0.08)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.auto_awesome,
                      color: AppColors.primaryA.withOpacity(0.3), size: 12)),
                Container(width: 24, height: 1, color: Colors.white.withOpacity(0.08)),
              ])),
            ]),
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
  const _AudioBtn({required this.icon, required this.size,
      required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(onTap != null ? 0.05 : 0.02),
        border: Border.all(
            color: Colors.white.withOpacity(onTap != null ? 0.08 : 0.03))),
      child: Icon(icon, color: color, size: size)),
  );
}

class _SnippetListTile extends StatelessWidget {
  final BookSnippetModel snippet;
  final int index;
  final bool isRead, isCurrent;
  final VoidCallback onTap, onAudioTap;
  const _SnippetListTile({required this.snippet, required this.index,
      required this.isRead, required this.isCurrent,
      required this.onTap, required this.onAudioTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCurrent ? AppColors.primaryA.withOpacity(0.08) : const Color(0xFF0F1624),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent ? AppColors.primaryA.withOpacity(0.35)
              : isRead ? const Color(0xFF10B981).withOpacity(0.2)
                  : Colors.white.withOpacity(0.05))),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isRead ? const Color(0xFF10B981).withOpacity(0.15)
                : isCurrent ? AppColors.primaryA.withOpacity(0.15)
                    : Colors.white.withOpacity(0.04),
            border: Border.all(
              color: isRead ? const Color(0xFF10B981).withOpacity(0.4)
                  : isCurrent ? AppColors.primaryA.withOpacity(0.5)
                      : Colors.white.withOpacity(0.08))),
          child: Icon(
            isRead ? Icons.check_rounded
                : isCurrent ? Icons.play_arrow_rounded : Icons.circle_outlined,
            color: isRead ? const Color(0xFF10B981)
                : isCurrent ? AppColors.primaryA : Colors.grey[700],
            size: 16)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(snippet.snippetTitle,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: isRead ? Colors.grey[600]
                      : isCurrent ? Colors.white : Colors.white70,
                  fontSize: 13, fontWeight: FontWeight.w600)),
          if (snippet.durationSeconds != null) ...[
            const SizedBox(height: 2),
            Text('${snippet.durationLabel} read',
                style: TextStyle(color: Colors.grey[700], fontSize: 11)),
          ],
        ])),
        GestureDetector(
          onTap: onAudioTap,
          child: Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFEC4899).withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFEC4899).withOpacity(0.25))),
            child: const Icon(Icons.headphones_rounded,
                color: Color(0xFFEC4899), size: 14))),
        const SizedBox(width: 6),
        Icon(Icons.chevron_right_rounded, color: Colors.grey[700], size: 18),
      ])),
  );
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MetaChip({required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.25))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 12),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    ]));
}

class _CompletionSheet extends StatelessWidget {
  final BookModel book;
  const _CompletionSheet({required this.book});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: const Color(0xFF0F1624),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.primaryA.withOpacity(0.3)),
      boxShadow: [BoxShadow(color: AppColors.primaryA.withOpacity(0.2),
          blurRadius: 40, spreadRadius: 4)]),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.primaryA, AppColors.primaryB]),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(
              color: AppColors.primaryA.withOpacity(0.4), blurRadius: 20)]),
        child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 32)),
      const SizedBox(height: 16),
      const Text('Book Completed! 🎉', style: TextStyle(color: Colors.white,
          fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text('You finished "${book.title}". Great job keeping your focus!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[400], fontSize: 13, height: 1.5)),
      const SizedBox(height: 20),
      GestureDetector(
        onTap: () { Navigator.pop(context); Navigator.pop(context); },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.primaryA, AppColors.primaryB]),
            borderRadius: BorderRadius.circular(14)),
          child: const Center(child: Text('Back to Library',
              style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 15))))),
    ]));
}

class _CoverPainter extends CustomPainter {
  final int seed;
  _CoverPainter(this.seed);
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (int i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        20 + rng.nextDouble() * 50, paint);
    }
  }
  @override
  bool shouldRepaint(_CoverPainter old) => old.seed != seed;
}