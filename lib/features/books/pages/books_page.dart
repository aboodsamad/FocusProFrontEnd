import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/book_model.dart';
import '../services/book_service.dart';
import 'book_detail_page.dart';

class BooksPage extends StatefulWidget {
  final bool audioMode;
  const BooksPage({super.key, this.audioMode = false});

  @override
  State<BooksPage> createState() => _BooksPageState();
}

class _BooksPageState extends State<BooksPage> with TickerProviderStateMixin {
  List<BookModel> _allBooks = [];
  List<BookModel> _filtered = [];
  bool _loading = true;
  String? _error;

  String _search = '';
  int _selectedLevel = 0;
  String _selectedCategory = 'All';

  final TextEditingController _searchCtrl = TextEditingController();
  late AnimationController _fadeCtrl;

  static const List<_LevelFilter> _levels = [
    _LevelFilter(0, 'All', AppColors.primary),
    _LevelFilter(1, 'Beginner', AppColors.secondary),
    _LevelFilter(2, 'Intermediate', Color(0xFFF97316)),
    _LevelFilter(3, 'Advanced', Color(0xFFEF4444)),
  ];

  // Card cover colors matching the HTML design
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

  static const List<IconData> _coverIcons = [
    Icons.menu_book_rounded,
    Icons.psychology_rounded,
    Icons.insights_rounded,
    Icons.self_improvement_rounded,
    Icons.history_edu_rounded,
    Icons.bolt_rounded,
    Icons.work_rounded,
    Icons.bubble_chart_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _loadBooks();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBooks() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final books = await BookService.getAllBooks();
      setState(() {
        _allBooks = books;
        _applyFilters();
        _loading = false;
      });
      _fadeCtrl.forward(from: 0);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _applyFilters() {
    var result = _allBooks;
    if (_selectedLevel != 0) {
      result = result.where((b) => b.level == _selectedLevel).toList();
    }
    if (_selectedCategory != 'All') {
      result = result.where((b) => b.category.toLowerCase() == _selectedCategory.toLowerCase()).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      result = result.where((b) => b.title.toLowerCase().contains(q) || b.author.toLowerCase().contains(q) || b.category.toLowerCase().contains(q)).toList();
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
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSearchBar(),
                    const SizedBox(height: 16),
                    _buildLevelChips(),
                    const SizedBox(height: 8),
                    _buildCategoryChips(),
                    const SizedBox(height: 16),
                    _buildBody(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: const Color(0xFFF0FBF5),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12,
        left: 16,
        right: 16,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.onSurfaceVariant, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Library',
              style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.menu_book_rounded,
                  color: AppColors.onSecondaryContainer, size: 14),
              const SizedBox(width: 6),
              Text(
                '${_allBooks.length} books',
                style: const TextStyle(
                  color: AppColors.onSecondaryContainer,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(color: AppColors.onSurface, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search by title, author or category...',
            hintStyle: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.onSurfaceVariant, size: 20),
            suffixIcon: _search.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() {
                        _search = '';
                        _applyFilters();
                      });
                    },
                    child: const Icon(Icons.close_rounded, color: AppColors.onSurfaceVariant, size: 18),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onChanged: (v) {
            setState(() {
              _search = v;
              _applyFilters();
            });
          },
        ),
      ),
    );
  }

  Widget _buildLevelChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _levels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = _levels[i];
          final selected = _selectedLevel == f.level;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedLevel = f.level;
                _applyFilters();
              });
              _fadeCtrl.forward(from: 0);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.outlineVariant,
                ),
              ),
              child: Text(
                f.label,
                style: TextStyle(
                  color: selected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryChips() {
    final cats = _categories.where((c) => c != 'All').toList();
    if (cats.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 36,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = cats[i];
          final selected = _selectedCategory == cat;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = selected ? 'All' : cat;
                _applyFilters();
              });
              _fadeCtrl.forward(from: 0);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.secondaryContainer
                    : AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? AppColors.secondary
                      : AppColors.outlineVariant,
                ),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  color: selected
                      ? AppColors.onSecondaryContainer
                      : AppColors.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
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
                  color: AppColors.errorContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wifi_off_rounded, color: AppColors.error, size: 32),
              ),
              const SizedBox(height: 16),
              const Text('Couldn\'t load books', style: TextStyle(color: AppColors.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Check your connection and try again', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _loadBooks,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                  child: const Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, color: AppColors.outlineVariant, size: 48),
              const SizedBox(height: 12),
              const Text('No books found', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 15)),
              const SizedBox(height: 6),
              const Text('Try a different search or filter', style: TextStyle(color: AppColors.outlineVariant, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeCtrl,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.68,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _filtered.length,
          itemBuilder: (ctx, i) => _BookCard(
            book: _filtered[i],
            index: i,
            coverColors: _coverColors,
            coverIcons: _coverIcons,
            onTap: () => Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, anim, __) => BookDetailPage(book: _filtered[i], audioMode: widget.audioMode),
                transitionsBuilder: (_, anim, __, child) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                    child: child,
                  ),
                ),
                transitionDuration: const Duration(milliseconds: 300),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Book Card ────────────────────────────────────────────────────────────────

class _BookCard extends StatefulWidget {
  final BookModel book;
  final int index;
  final List<Color> coverColors;
  final List<IconData> coverIcons;
  final VoidCallback onTap;
  const _BookCard({required this.book, required this.index, required this.coverColors, required this.coverIcons, required this.onTap});

  @override
  State<_BookCard> createState() => _BookCardState();
}

class _BookCardState extends State<_BookCard> {
  bool _pressed = false;

  Color get _coverColor => widget.coverColors[widget.index % widget.coverColors.length];
  IconData get _coverIcon => widget.coverIcons[widget.index % widget.coverIcons.length];

  String get _levelLabel => widget.book.levelLabel;

  bool get _isLightCover {
    final r = (_coverColor.r * 255.0).round().clamp(0, 255);
    final g = (_coverColor.g * 255.0).round().clamp(0, 255);
    final b = (_coverColor.b * 255.0).round().clamp(0, 255);
    final luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
    return luminance > 0.6;
  }

  @override
  Widget build(BuildContext context) {
    final textOnCover = _isLightCover ? AppColors.onSurface : Colors.white;
    final iconOnCover = _isLightCover
        ? AppColors.onSurface.withValues(alpha: 0.3)
        : Colors.white.withValues(alpha: 0.4);

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover area
            Expanded(
              flex: 4,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: _coverColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Icon(_coverIcon, color: iconOnCover, size: 60),
                    ),
                  ),
                  // Level badge
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isLightCover ? Colors.black.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 5, height: 5, decoration: BoxDecoration(color: textOnCover, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          Text(
                            _levelLabel,
                            style: TextStyle(color: textOnCover, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Info section
            Padding(
              padding: const EdgeInsets.only(top: 10, left: 2, right: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      fontFamily: 'Manrope',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.book.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11),
                  ),
                  if (widget.book.totalPages != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.auto_stories_rounded, color: AppColors.secondary, size: 12),
                        const SizedBox(width: 3),
                        Text(
                          '${widget.book.totalPages} pages',
                          style: const TextStyle(color: AppColors.onSecondaryContainer, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Level filter data ─────────────────────────────────────────────────────────

class _LevelFilter {
  final int level;
  final String label;
  final Color color;
  const _LevelFilter(this.level, this.label, this.color);
}
