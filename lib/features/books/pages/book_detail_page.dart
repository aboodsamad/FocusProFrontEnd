import 'dart:math' as math;
import 'dart:typed_data';
import 'package:capstone_front_end/core/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _ttsPlaying = false;
  bool _ttsLoading = false;
  double _ttsProgress = 0.0;
  double _ttsSpeed = 1.0;
  bool _speedChanging = false;
  final Set<int> _completedChapters = {};
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;

  // ── Audio pre-fetch cache (index → bytes) ─────────────────────────────────
  final Map<int, Uint8List> _audioCache = {};

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
    _initAudioPlayer();
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

  void _initAudioPlayer() {
    _audioPlayer.playbackEventStream.listen(
      (_) {},
      onError: (Object e, StackTrace st) {
        debugPrint('just_audio playback error: $e');
      },
    );

    // Track real position and duration for accurate progress/time display
    _audioPlayer.positionStream.listen((position) {
      if (!mounted) return;
      setState(() {
        _audioPosition = position;
        if (_audioDuration.inMilliseconds > 0) {
          _ttsProgress = (position.inMilliseconds / _audioDuration.inMilliseconds).clamp(0.0, 1.0);
        }
      });
    });

    _audioPlayer.durationStream.listen((duration) {
      if (!mounted) return;
      setState(() => _audioDuration = duration ?? Duration.zero);
    });

    _audioPlayer.playerStateStream.listen((state) async {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed) {
        setState(() { _ttsPlaying = false; });
        for (final c in _barCtrls) c.stop();
        final completedIdx = _currentIndex;
        final snippetId = _snippets[completedIdx].id;
        final token = await AuthService.getToken() ?? '';
        final passed = await showSnippetCheckSheet(context, snippetId: snippetId, token: token);
        if (!mounted) return;
        if (passed) {
          _completedChapters.add(completedIdx);
          setState(() {});
          if (_currentIndex < _snippets.length - 1) {
            final next = _currentIndex + 1;
            Future.delayed(const Duration(milliseconds: 600), () {
              if (!mounted) return;
              setState(() { _currentIndex = next; _ttsProgress = 0; _audioDuration = Duration.zero; _audioPosition = Duration.zero; });
              _pageController.animateToPage(next, duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
              if (_audioMode) {
                Future.delayed(const Duration(milliseconds: 400), () {
                  if (mounted) _ttsPlay();
                });
              }
            });
          } else {
            _showCompletionSheet();
          }
        } else {
          // Failed test — stay on current chapter
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Pass the quiz (2/3 correct) to unlock the next chapter.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } else if (state.playing) {
        if (!mounted) return;
        if (!_ttsPlaying) {
          setState(() => _ttsPlaying = true);
          for (final c in _barCtrls) c.repeat(reverse: true);
        }
      } else if (!state.playing &&
          state.processingState != ProcessingState.loading &&
          state.processingState != ProcessingState.buffering) {
        if (mounted && _ttsPlaying && !_speedChanging) {
          setState(() => _ttsPlaying = false);
          for (final c in _barCtrls) c.stop();
        }
      }
    });
  }


  @override
  void dispose() {
    _audioPlayer.dispose();
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
      // Pre-fetch audio for first 2 snippets in background so play is instant
      _prefetchAudio(0);
      if (snippets.length > 1) _prefetchAudio(1);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String get _currentText => _snippets.isNotEmpty ? _snippets[_currentIndex].snippetText : '';

  // Pre-fetch audio in the background and store in local cache
  Future<void> _prefetchAudio(int index) async {
    if (index < 0 || index >= _snippets.length) return;
    if (_audioCache.containsKey(index)) return; // already cached
    final text = _snippets[index].snippetText;
    if (text.isEmpty) return;
    try {
      final token = await AuthService.getToken() ?? '';
      final resp = await http.post(
        Uri.parse('${AuthService.baseUrl}/tts'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'text': text}),
      ).timeout(const Duration(seconds: 90));
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        _audioCache[index] = resp.bodyBytes;
        debugPrint('TTS pre-fetch done for snippet $index (${resp.bodyBytes.length} bytes)');
      }
    } catch (e) {
      debugPrint('TTS pre-fetch failed for snippet $index: $e');
    }
  }

  Future<void> _ttsPlay() async {
    if (_currentText.isEmpty || !mounted) return;
    try { await _audioPlayer.stop(); } catch (_) {}
    if (!mounted) return;
    if (mounted) setState(() { _ttsPlaying = false; _ttsProgress = 0; _ttsLoading = true; _audioDuration = Duration.zero; _audioPosition = Duration.zero; });

    try {
      // ── Use local cache if available (instant play) ──
      if (_audioCache.containsKey(_currentIndex)) {
        final cachedBytes = _audioCache[_currentIndex]!;
        await _audioPlayer.setAudioSource(_BytesAudioSource(cachedBytes));
        await _audioPlayer.setSpeed(_ttsSpeed);
        if (mounted) setState(() => _ttsLoading = false);
        await _audioPlayer.play();
        // Pre-fetch the next snippet while current is playing
        _prefetchAudio(_currentIndex + 1);
        return;
      }

      final token = await AuthService.getToken() ?? '';
      final resp = await http.post(
        Uri.parse('${AuthService.baseUrl}/tts'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'text': _currentText}),
      ).timeout(const Duration(seconds: 60));

      if (!mounted) return;

      if (resp.statusCode == 503) {
        // Render free-tier backend is waking up from sleep
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Server is starting up, please try again in a few seconds...'),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      if (resp.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Audio unavailable (${resp.statusCode}), please try again.'),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      final bytes = resp.bodyBytes;
      if (bytes.isEmpty) return;

      // Store in cache so next play is instant
      _audioCache[_currentIndex] = bytes;

      await _audioPlayer.setAudioSource(_BytesAudioSource(bytes));
      await _audioPlayer.setSpeed(_ttsSpeed);
      await _audioPlayer.play();
      // Pre-fetch next snippet while current plays
      _prefetchAudio(_currentIndex + 1);
    } catch (e) {
      debugPrint('TTS error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audio playback failed. Please try again.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _ttsLoading = false);
    }
  }

  Future<void> _ttsStop() async {
    if (mounted) setState(() { _ttsPlaying = false; _ttsProgress = 0; _audioPosition = Duration.zero; });
    for (final c in _barCtrls) c.stop();
    try { await _audioPlayer.stop(); } catch (_) {}
  }

  Future<void> _ttsPauseResume() async {
    if (_ttsPlaying) {
      try { await _audioPlayer.pause(); } catch (_) {}
    } else {
      final ps = _audioPlayer.processingState;
      if (ps == ProcessingState.ready || ps == ProcessingState.buffering) {
        try { await _audioPlayer.play(); } catch (_) {}
      } else {
        await _ttsPlay();
      }
    }
  }

  Future<void> _seekRelative(int seconds) async {
    if (_audioDuration == Duration.zero) return;
    final raw = _audioPosition + Duration(seconds: seconds);
    final newPos = raw < Duration.zero ? Duration.zero : (raw > _audioDuration ? _audioDuration : raw);
    try { await _audioPlayer.seek(newPos); } catch (_) {}
  }

  Future<void> _seekTo(double fraction) async {
    if (_audioDuration == Duration.zero) return;
    final ms = (fraction * _audioDuration.inMilliseconds).round();
    try { await _audioPlayer.seek(Duration(milliseconds: ms)); } catch (_) {}
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool _isChapterUnlocked(int index) {
    if (index <= 0) return true;
    return _completedChapters.contains(index - 1);
  }

  Future<void> _setSpeed(double speed) async {
    _ttsSpeed = speed;
    _speedChanging = true;
    if (mounted) setState(() {});
    try { await _audioPlayer.setSpeed(speed); } catch (_) {}
    _speedChanging = false;
  }

  BookSnippetModel? get _current => _snippets.isNotEmpty ? _snippets[_currentIndex] : null;

  Future<void> _goTo(int i, {bool autoPlay = false}) async {
    if (i < 0 || i >= _snippets.length || !mounted) return;
    try { await _audioPlayer.stop(); } catch (_) {}
    if (!mounted) return;
    setState(() { _ttsPlaying = false; _ttsProgress = 0; _audioPosition = Duration.zero; _audioDuration = Duration.zero; _currentIndex = i; });
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
    if (!mounted) return;
    if (passed) {
      _completedChapters.add(completedIdx);
      setState(() {});
      if (_currentIndex < _snippets.length - 1) {
        _goTo(_currentIndex + 1);
      } else {
        _showCompletionSheet();
      }
    } else {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pass the quiz (2/3 correct) to unlock the next chapter.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _showCompletionSheet() {
    try { _audioPlayer.stop(); } catch (_) {}
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: () {
                      final url = widget.book.bookPagesUrl;
                      if (url == null || url.isEmpty) {
                        return _BookCoverFallback(color: _coverColor, title: widget.book.title);
                      }
                      final isNetwork = url.startsWith('http');
                      return isNetwork
                          ? Image.network(
                              url,
                              fit: BoxFit.cover,
                              width: 120,
                              height: 180,
                              errorBuilder: (_, __, ___) => _BookCoverFallback(
                                color: _coverColor, title: widget.book.title),
                            )
                          : Image.asset(
                              url,
                              fit: BoxFit.cover,
                              width: 120,
                              height: 180,
                              errorBuilder: (_, __, ___) => _BookCoverFallback(
                                color: _coverColor, title: widget.book.title),
                            );
                    }(),
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
              final unlocked = _isChapterUnlocked(i);

              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: GestureDetector(
                  onTap: unlocked
                      ? () => setState(() { _currentIndex = i; _readingMode = true; })
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Complete the previous chapter first!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                  child: Opacity(
                    opacity: unlocked ? 1.0 : 0.5,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isCurrent && !done ? AppColors.primaryContainer : AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border(
                          left: BorderSide(
                            color: done ? AppColors.secondary : isCurrent && unlocked ? AppColors.onTertiaryContainer : Colors.transparent,
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
                                  : unlocked
                                  ? Icons.play_circle_rounded
                                  : Icons.lock_rounded,
                              color: done
                                  ? AppColors.onSecondaryContainer
                                  : unlocked
                                  ? (isCurrent ? Colors.white : AppColors.onSurfaceVariant)
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
                                    color: isCurrent && !done ? Colors.white : done ? AppColors.primary : AppColors.onSurface,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Manrope',
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  done ? 'Completed' : unlocked ? (isCurrent ? 'Next up' : 'Available') : 'Locked',
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
                      const SizedBox(height: 24),
                      _buildAudioCoverArt(),
                      const SizedBox(height: 28),
                      _buildAudioTitleInfo(),
                      const SizedBox(height: 24),
                      _buildTtsProgressBar(),
                      const SizedBox(height: 20),
                      _buildSpeedSelector(),
                      const SizedBox(height: 24),
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
    final bookUrl = widget.book.bookPagesUrl;
    final hasImage = bookUrl != null && bookUrl.isNotEmpty;
    final isNetworkUrl = hasImage && bookUrl.startsWith('http');

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, __) => Transform.scale(
        scale: _ttsPlaying ? _pulseAnim.value : 1.0,
        child: Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _coverColor,
            boxShadow: [
              BoxShadow(
                color: _coverColor.withOpacity(_ttsPlaying ? 0.55 : 0.30),
                blurRadius: _ttsPlaying ? 60 : 30,
                spreadRadius: _ttsPlaying ? 8 : 2,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: AppColors.secondaryFixed.withOpacity(_ttsPlaying ? 0.15 : 0.05),
                blurRadius: _ttsPlaying ? 80 : 40,
                spreadRadius: _ttsPlaying ? 4 : 0,
              ),
            ],
          ),
          child: ClipOval(
            child: hasImage
                ? (isNetworkUrl
                    ? Image.network(
                        bookUrl,
                        width: 240,
                        height: 240,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _AudioCoverFallbackCircle(
                          color: _coverColor,
                          title: widget.book.title,
                          author: widget.book.author,
                        ),
                      )
                    : Image.asset(
                        bookUrl,
                        width: 240,
                        height: 240,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _AudioCoverFallbackCircle(
                          color: _coverColor,
                          title: widget.book.title,
                          author: widget.book.author,
                        ),
                      ))
                : _AudioCoverFallbackCircle(
                    color: _coverColor,
                    title: widget.book.title,
                    author: widget.book.author,
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
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            thumbColor: AppColors.secondaryFixed,
            activeTrackColor: AppColors.secondaryFixed,
            inactiveTrackColor: const Color(0xFF374151),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            overlayColor: AppColors.secondaryFixed.withValues(alpha: 0.15),
          ),
          child: Slider(
            value: _ttsProgress.clamp(0.0, 1.0),
            onChanged: (v) => setState(() => _ttsProgress = v),
            onChangeEnd: (v) => _seekTo(v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_audioPosition),
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5),
              ),
              Text(
                _formatDuration(_audioDuration),
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5),
              ),
            ],
          ),
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
    final canGoNext = _currentIndex < _snippets.length - 1 && _isChapterUnlocked(_currentIndex + 1);
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
          onTap: () => _seekRelative(-10),
        ),
        GestureDetector(
          onTap: _ttsLoading ? null : _ttsPauseResume,
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
            child: _ttsLoading
                ? const Padding(
                    padding: EdgeInsets.all(22),
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 3,
                    ),
                  )
                : Icon(
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
          onTap: () => _seekRelative(10),
        ),
        _AudioBtn(
          icon: Icons.skip_next_rounded,
          size: 28,
          color: canGoNext ? const Color(0xFF9CA3AF) : const Color(0xFF374151),
          onTap: canGoNext ? () => _goTo(_currentIndex + 1, autoPlay: _ttsPlaying) : null,
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
          final unlocked = _isChapterUnlocked(i);
          return GestureDetector(
            onTap: unlocked
                ? () => _goTo(i, autoPlay: _ttsPlaying)
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Complete the previous chapter first!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
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
              child: Opacity(
                opacity: unlocked ? 1.0 : 0.45,
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
                          : !unlocked
                          ? const Icon(Icons.lock_rounded, color: Color(0xFF6B7280), size: 16)
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
                            Text(s.durationLabel, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
                        ],
                      ),
                    ),
                    Icon(
                      unlocked ? Icons.play_circle_rounded : Icons.lock_outline_rounded,
                      color: active ? AppColors.secondaryFixed : const Color(0xFF374151),
                      size: 20,
                    ),
                  ],
                ),
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
                physics: const NeverScrollableScrollPhysics(),
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


// Circular fallback used in the audio player
class _AudioCoverFallbackCircle extends StatelessWidget {
  final Color color;
  final String title;
  final String author;
  const _AudioCoverFallbackCircle({required this.color, required this.title, required this.author});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.65)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.menu_book_rounded, color: Colors.white.withOpacity(0.25), size: 90),
          Positioned(
            bottom: 44,
            left: 24,
            right: 24,
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, height: 1.3, fontFamily: 'Manrope'),
            ),
          ),
          Positioned(
            bottom: 28,
            left: 24,
            right: 24,
            child: Text(
              author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioCoverFallback extends StatelessWidget {
  final Color color;
  final String title;
  final String author;
  const _AudioCoverFallback({required this.color, required this.title, required this.author});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 280,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Center(child: Icon(Icons.menu_book_rounded, color: Colors.white.withOpacity(0.2), size: 80)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, height: 1.3, fontFamily: 'Manrope'),
                ),
                const SizedBox(height: 4),
                Text(
                  author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookCoverFallback extends StatelessWidget {
  final Color color;
  final String title;
  const _BookCoverFallback({required this.color, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      child: Stack(
        children: [
          Center(child: Icon(Icons.menu_book_rounded, color: Colors.white.withOpacity(0.35), size: 48)),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(title, textAlign: TextAlign.center, maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Feeds raw MP3 bytes (from ElevenLabs) into just_audio without writing to disk.
class _BytesAudioSource extends StreamAudioSource {
  final Uint8List _bytes;
  _BytesAudioSource(this._bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_bytes.sublist(start, end)),
      contentType: 'audio/mpeg',
    );
  }
}
