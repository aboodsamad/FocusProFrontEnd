import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../models/game_item.dart';
import '../models/game_registry.dart';
import '../widgets/game_hub_card.dart';
import 'level_roadmap_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GamesHubPage
// ─────────────────────────────────────────────────────────────────────────────

/// The game-selection lobby.
/// Shows a featured card, category filter chips and a 2-column grid of games.
/// Navigate here from HomeScreen instead of directly to any single game.
class GamesHubPage extends StatefulWidget {
  const GamesHubPage({super.key});

  @override
  State<GamesHubPage> createState() => _GamesHubPageState();
}

class _GamesHubPageState extends State<GamesHubPage>
    with SingleTickerProviderStateMixin {

  // ── State ──────────────────────────────────────────────────────────────────

  GameCategory? _activeFilter; // null = All
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Filtered list ──────────────────────────────────────────────────────────

  List<GameItem> get _filteredGames {
    if (_activeFilter == null) return GameRegistry.all;
    return GameRegistry.all
        .where((g) => g.category == _activeFilter)
        .toList();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _openGame(GameItem game) {
    if (GameRegistry.hasRoadmap(game.id)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LevelRoadmapPage(
            gameId:      game.id,
            title:       game.title,
            color:       Color(game.colorValue),
            totalLevels: GameRegistry.totalLevels(game.id),
            pageBuilder: (level) => GameRegistry.levelPageFor(game.id, level)!,
          ),
        ),
      );
      return;
    }
    final page = GameRegistry.pageFor(game.id);
    if (page == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080D1A),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildStatsBar()),
              SliverToBoxAdapter(child: _buildFeatured()),
              SliverToBoxAdapter(child: _buildCategoryFilters()),
              SliverToBoxAdapter(child: _buildSectionLabel()),
              _buildGrid(),
              const SliverToBoxAdapter(child: SizedBox(height: 48)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          // Back button — same style as books_page
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width:  40,
              height: 40,
              decoration: BoxDecoration(
                color:        Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border:       Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.grey[400], size: 16),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Brain Games',
                style: TextStyle(
                  color:      Colors.white,
                  fontSize:   20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Train your focus & memory',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          // Game count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color:        AppColors.primaryA.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border:       Border.all(
                  color: AppColors.primaryA.withOpacity(0.28)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.videogame_asset_rounded,
                  color: AppColors.primaryA, size: 14),
              const SizedBox(width: 6),
              Text(
                '${GameRegistry.available.length} playable',
                style: TextStyle(
                  color:      AppColors.primaryA,
                  fontSize:   11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Stats bar ──────────────────────────────────────────────────────────────

  Widget _buildStatsBar() {
    final stats = [
      _StatItem('Games',    '${GameRegistry.all.length}',       Icons.sports_esports_outlined, AppColors.primaryA),
      _StatItem('Memory',   '${GameRegistry.byCategory(GameCategory.memory).length}',    Icons.psychology_outlined,       const Color(0xFF7B6FFF)),
      _StatItem('Logic',    '${GameRegistry.byCategory(GameCategory.logic).length}',     Icons.lightbulb_outline,         const Color(0xFF6366F1)),
      _StatItem('Speed',    '${GameRegistry.byCategory(GameCategory.speed).length}',     Icons.bolt_outlined,             const Color(0xFFF59E0B)),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: stats.map((s) => Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _MiniStatCard(stat: s),
          ),
        )).toList(),
      ),
    );
  }

  // ── Featured card ──────────────────────────────────────────────────────────

  Widget _buildFeatured() {
    // Featured = first available game
    final featured = GameRegistry.available.isNotEmpty
        ? GameRegistry.available.first
        : null;

    if (featured == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label: "Today's Pick"),
          const SizedBox(height: 12),
          GameHubFeaturedCard(
            game:  featured,
            onTap: () => _openGame(featured),
          ),
        ],
      ),
    );
  }

  // ── Category filter chips ──────────────────────────────────────────────────

  Widget _buildCategoryFilters() {
    final filters = <_FilterItem>[
      _FilterItem(null,                    'All',       Icons.apps_rounded),
      _FilterItem(GameCategory.memory,     'Memory',    Icons.psychology_outlined),
      _FilterItem(GameCategory.logic,      'Logic',     Icons.lightbulb_outline),
      _FilterItem(GameCategory.speed,      'Speed',     Icons.bolt_outlined),
      _FilterItem(GameCategory.attention,  'Attention', Icons.remove_red_eye_outlined),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection:  Axis.horizontal,
          padding:          const EdgeInsets.symmetric(horizontal: 20),
          itemCount:        filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final f       = filters[i];
            final active  = _activeFilter == f.category;
            return GestureDetector(
              onTap: () => setState(() {
                _activeFilter = f.category;
                _fadeCtrl.forward(from: 0.5);
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primaryA.withOpacity(0.18)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active
                        ? AppColors.primaryA.withOpacity(0.55)
                        : Colors.white.withOpacity(0.08),
                    width: active ? 1.5 : 1.0,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    f.icon,
                    size:  13,
                    color: active ? AppColors.primaryA : Colors.grey[500],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    f.label,
                    style: TextStyle(
                      color:      active ? AppColors.primaryA : Colors.grey[500],
                      fontSize:   12,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Section label ──────────────────────────────────────────────────────────

  Widget _buildSectionLabel() {
    final count = _filteredGames.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
      child: Row(
        children: [
          const _SectionLabel(label: 'All Games'),
          const Spacer(),
          Text(
            '$count game${count == 1 ? '' : 's'}',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ── Game grid ──────────────────────────────────────────────────────────────

  SliverPadding _buildGrid() {
    final games = _filteredGames;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, i) => GameHubCard(
            game:  games[i],
            onTap: games[i].isAvailable ? () => _openGame(games[i]) : null,
          ),
          childCount: games.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:   2,
          crossAxisSpacing: 12,
          mainAxisSpacing:  12,
          childAspectRatio: 0.82,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small private helpers
// ─────────────────────────────────────────────────────────────────────────────

class _StatItem {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatItem(this.label, this.value, this.icon, this.color);
}

class _MiniStatCard extends StatelessWidget {
  final _StatItem stat;
  const _MiniStatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color:        const Color(0xFF0F1624),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(stat.icon, color: stat.color, size: 16),
          const SizedBox(height: 6),
          Text(
            stat.value,
            style: TextStyle(
              color:      stat.color,
              fontSize:   16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            stat.label,
            style: TextStyle(color: Colors.grey[600], fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _FilterItem {
  final GameCategory? category;
  final String label;
  final IconData icon;
  const _FilterItem(this.category, this.label, this.icon);
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      color:      Colors.white,
      fontSize:   16,
      fontWeight: FontWeight.bold,
    ),
  );
}