import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/book_model.dart';
import '../services/book_service.dart';
import 'book_detail_page.dart';

class BooksPage extends StatefulWidget {
  /// If true, tapping a book opens it directly in audio (TTS) mode
  final bool audioMode;
  const BooksPage({Key? key, this.audioMode = false}) : super(key: key);

  @override
  State<BooksPage> createState() => _BooksPageState();
}

class _BooksPageState extends State<BooksPage> with TickerProviderStateMixin {
  List<BookModel> _allBooks = [];
  List<BookModel> _filtered = [];
  bool _loading = true;
  String? _error;

  String _search = '';
  int _selectedLevel = 0; // 0 = All
  String _selectedCategory = 'All';

  final TextEditingController _searchCtrl = TextEditingController();
  late AnimationController _fadeCtrl;

  static const List<_LevelFilter> _levels = [
    _LevelFilter(0, 'All', Color(0xFF667eea)),
    _LevelFilter(1, 'Beginner', Color(0xFF10B981)),
    _LevelFilter(2, 'Intermediate', Color(0xFFF97316)),
    _LevelFilter(3, 'Advanced', Color(0xFFEF4444)),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _loadBooks();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBooks() async {
    setState(() { _loading = true; _error = null; });
    try {
      final books = await BookService.getAllBooks();
      setState(() {
        _allBooks = books;
        _applyFilters();
        _loading = false;
      });
      _fadeCtrl.forward(from: 0);
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _applyFilters() {
    var result = _allBooks;
    if (_selectedLevel != 0) {
      result = result.where((b) => b.level == _selectedLevel).toList();
    }
    if (_selectedCategory != 'All') {
      result = result
          .where((b) => b.category.toLowerCase() == _selectedCategory.toLowerCase())
          .toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      result = result
          .where((b) =>
              b.title.toLowerCase().contains(q) ||
              b.author.toLowerCase().contains(q) ||
              b.category.toLowerCase().contains(q))
          .toList();
    }
    _filtered = result;
  }

  List<String> get _categories {
    final cats = {'All', ..._allBooks.map((b) => b.category)};
    return cats.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080D1A),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildLevelChips(),
            if (_categories.length > 1) _buildCategoryChips(),
            const SizedBox(height: 8),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white70, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Library', style: TextStyle(
                    color: Colors.white, fontSize: 22,
                    fontWeight: FontWeight.bold, letterSpacing: -0.3)),
                SizedBox(height: 2),
                Text('Focus-boosting reads', style: TextStyle(
                    color: Color(0xFF667eea), fontSize: 12,
                    fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          _buildBookCountBadge(),
        ],
      ),
    );
  }

  Widget _buildBookCountBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF667eea), Color(0xFF764ba2)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF667eea).withOpacity(0.3),
              blurRadius: 12, spreadRadius: 1)
        ],
      ),
      child: Text(
        '${_filtered.length} books',
        style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFF0F1624),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search by title, author or category…',
            hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
            prefixIcon: Icon(Icons.search_rounded,
                color: Colors.grey[600], size: 20),
            suffixIcon: _search.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() { _search = ''; _applyFilters(); });
                    },
                    child: Icon(Icons.close_rounded,
                        color: Colors.grey[600], size: 18),
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          ),
          onChanged: (v) {
            setState(() { _search = v; _applyFilters(); });
          },
        ),
      ),
    );
  }

  Widget _buildLevelChips() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        scrollDirection: Axis.horizontal,
        itemCount: _levels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = _levels[i];
          final selected = _selectedLevel == f.level;
          return GestureDetector(
            onTap: () {
              setState(() { _selectedLevel = f.level; _applyFilters(); });
              _fadeCtrl.forward(from: 0);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? f.color.withOpacity(0.2)
                    : Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? f.color.withOpacity(0.6)
                      : Colors.white.withOpacity(0.08),
                  width: selected ? 1.5 : 1,
                ),
                boxShadow: selected
                    ? [BoxShadow(
                        color: f.color.withOpacity(0.3), blurRadius: 10)]
                    : [],
              ),
              child: Text(f.label,
                  style: TextStyle(
                      color: selected ? f.color : Colors.grey[500],
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final cat = _categories[i];
          final selected = _selectedCategory == cat;
          return GestureDetector(
            onTap: () {
              setState(() { _selectedCategory = cat; _applyFilters(); });
              _fadeCtrl.forward(from: 0);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primaryA.withOpacity(0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? AppColors.primaryA.withOpacity(0.5)
                      : Colors.white.withOpacity(0.06),
                ),
              ),
              child: Text(cat,
                  style: TextStyle(
                      color: selected ? AppColors.primaryA : Colors.grey[600],
                      fontSize: 11, fontWeight: FontWeight.w500)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 40, height: 40,
              child: CircularProgressIndicator(
                  color: AppColors.primaryA, strokeWidth: 2.5),
            ),
            const SizedBox(height: 16),
            Text('Loading library…',
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wifi_off_rounded,
                    color: Color(0xFFEF4444), size: 32),
              ),
              const SizedBox(height: 16),
              const Text('Couldn\'t load books',
                  style: TextStyle(color: Colors.white,
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Check your connection and try again',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _loadBooks,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [
                      AppColors.primaryA, AppColors.primaryB
                    ]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Retry',
                      style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, color: Colors.grey[700], size: 48),
            const SizedBox(height: 12),
            Text('No books found',
                style: TextStyle(color: Colors.grey[500], fontSize: 15)),
            const SizedBox(height: 6),
            Text('Try a different search or filter',
                style: TextStyle(color: Colors.grey[700], fontSize: 12)),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeCtrl,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
          childAspectRatio: 0.62,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _filtered.length,
        itemBuilder: (ctx, i) => _BookCard(
          book: _filtered[i],
          index: i,
          onTap: () => Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, anim, __) =>
                  BookDetailPage(book: _filtered[i], audioMode: widget.audioMode),
              transitionsBuilder: (_, anim, __, child) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                      begin: const Offset(0.05, 0), end: Offset.zero)
                      .animate(CurvedAnimation(
                          parent: anim, curve: Curves.easeOut)),
                  child: child,
                ),
              ),
              transitionDuration: const Duration(milliseconds: 300),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Book Card ───────────────────────────────────────────────────────────────

class _BookCard extends StatefulWidget {
  final BookModel book;
  final int index;
  final VoidCallback onTap;
  const _BookCard({
    required this.book,
    required this.index,
    required this.onTap,
  });

  @override
  State<_BookCard> createState() => _BookCardState();
}

class _BookCardState extends State<_BookCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _shimCtrl;

  // Deterministic "cover" palette per card
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

  List<Color> get _palette =>
      _palettes[widget.index % _palettes.length];

  @override
  void initState() {
    super.initState();
    _shimCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat();
  }

  @override
  void dispose() {
    _shimCtrl.dispose();
    super.dispose();
  }

  Color get _levelColor {
    switch (widget.book.level) {
      case 1: return const Color(0xFF10B981);
      case 2: return const Color(0xFFF97316);
      case 3: return const Color(0xFFEF4444);
      default: return AppColors.primaryA;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F1624),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: _palette[0].withOpacity(0.2), width: 1),
            boxShadow: [
              BoxShadow(
                  color: _palette[0].withOpacity(0.15),
                  blurRadius: 20, spreadRadius: 1),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Book cover
              Expanded(
                flex: 5,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(17)),
                    gradient: LinearGradient(
                      colors: _palette,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Decorative pattern
                      Positioned.fill(child: _CoverPattern(seed: widget.index)),
                      // Shimmer line
                      AnimatedBuilder(
                        animation: _shimCtrl,
                        builder: (_, __) => Positioned(
                          top: -40,
                          left: -60 +
                              _shimCtrl.value *
                                  (MediaQuery.of(context).size.width + 120),
                          child: Transform.rotate(
                            angle: -0.5,
                            child: Container(
                              width: 30,
                              height: 200,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0),
                                    Colors.white.withOpacity(0.08),
                                    Colors.white.withOpacity(0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Book icon
                      Center(
                        child: Icon(
                          Icons.menu_book_rounded,
                          color: Colors.white.withOpacity(0.25),
                          size: 44,
                        ),
                      ),
                      // Level badge
                      Positioned(
                        top: 10, right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.15)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6, height: 6,
                                decoration: BoxDecoration(
                                    color: _levelColor,
                                    shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 4),
                              Text(widget.book.levelLabel,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      // Audio badge
                      if (widget.book.audioUrl != null)
                        Positioned(
                          bottom: 10, right: 10,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.15)),
                            ),
                            child: const Icon(Icons.headphones_rounded,
                                color: Colors.white70, size: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Info section
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category tag
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _palette[0].withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.book.category.toUpperCase(),
                          style: TextStyle(
                              color: _palette[0],
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            height: 1.3),
                      ),
                      const Spacer(),
                      Text(
                        widget.book.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 10),
                      ),
                      if (widget.book.totalPages != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.auto_stories_rounded,
                                color: Colors.grey[700], size: 10),
                            const SizedBox(width: 3),
                            Text('${widget.book.totalPages} pages',
                                style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 10)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Decorative cover pattern ────────────────────────────────────────────────

class _CoverPattern extends StatelessWidget {
  final int seed;
  const _CoverPattern({required this.seed});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PatternPainter(seed),
    );
  }
}

class _PatternPainter extends CustomPainter {
  final int seed;
  _PatternPainter(this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 0; i < 6; i++) {
      final r = 20.0 + rng.nextDouble() * 40;
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), r, paint);
    }

    for (int i = 0; i < 4; i++) {
      final x1 = rng.nextDouble() * size.width;
      final y1 = rng.nextDouble() * size.height;
      final x2 = rng.nextDouble() * size.width;
      final y2 = rng.nextDouble() * size.height;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }
  }

  @override
  bool shouldRepaint(_PatternPainter old) => old.seed != seed;
}

// ── Level filter data ───────────────────────────────────────────────────────

class _LevelFilter {
  final int level;
  final String label;
  final Color color;
  const _LevelFilter(this.level, this.label, this.color);
}
