import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../models/game_item.dart';
import '../models/game_registry.dart';
import '../widgets/game_hub_card.dart';
import 'level_roadmap_page.dart';

class GamesHubPage extends StatefulWidget {
  const GamesHubPage({super.key});

  @override
  State<GamesHubPage> createState() => _GamesHubPageState();
}

class _GamesHubPageState extends State<GamesHubPage>
    with SingleTickerProviderStateMixin {

  GameCategory? _activeFilter;
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

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

  List<GameItem> get _filteredGames {
    if (_activeFilter == null) return GameRegistry.all;
    return GameRegistry.all.where((g) => g.category == _activeFilter).toList();
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
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
        ],
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
              width:  40,
              height: 40,
              decoration: BoxDecoration(
                color:        AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border:       Border.all(color: AppColors.outlineVariant),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.onSurfaceVariant, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Brain Games',
                style: TextStyle(
                  color:      AppColors.primary,
                  fontSize:   20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Train your focus & memory',
                style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color:        AppColors.secondaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.videogame_asset_rounded,
                  color: AppColors.onSecondaryContainer, size: 14),
              const SizedBox(width: 6),
              Text(
                '${GameRegistry.available.length} playable',
                style: const TextStyle(
                  color:      AppColors.onSecondaryContainer,
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

  Widget _buildStatsBar() {
    final stats = [
      _StatItem('Games',  '${GameRegistry.all.length}',                                    Icons.sports_esports_outlined,  AppColors.primary),
      _StatItem('Memory', '${GameRegistry.byCategory(GameCategory.memory).length}',        Icons.psychology_outlined,       AppColors.secondary),
      _StatItem('Logic',  '${GameRegistry.byCategory(GameCategory.logic).length}',         Icons.lightbulb_outline,         const Color(0xFF7C3AED)),
      _StatItem('Speed',  '${GameRegistry.byCategory(GameCategory.speed).length}',         Icons.bolt_outlined,             const Color(0xFFF59E0B)),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
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

  Widget _buildFeatured() {
    final featured = GameRegistry.available.isNotEmpty
        ? GameRegistry.available.first
        : null;
    if (featured == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel(label: "Today's Pick"),
          const SizedBox(height: 12),
          GameHubFeaturedCard(
            game:  featured,
            onTap: () => _openGame(featured),
          ),
        ],
      ),
    );
  }

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
          padding:          const EdgeInsets.symmetric(horizontal: 16),
          itemCount:        filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final f      = filters[i];
            final active = _activeFilter == f.category;
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
                      ? AppColors.primary
                      : AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active
                        ? AppColors.primary
                        : AppColors.outlineVariant,
                    width: 1.0,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    f.icon,
                    size:  13,
                    color: active ? AppColors.onPrimary : AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    f.label,
                    style: TextStyle(
                      color:      active ? AppColors.onPrimary : AppColors.onSurfaceVariant,
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

  Widget _buildSectionLabel() {
    final count = _filteredGames.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
      child: Row(
        children: [
          const _SectionLabel(label: 'All Games'),
          const Spacer(),
          Text(
            '$count game${count == 1 ? '' : 's'}',
            style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }

  SliverPadding _buildGrid() {
    final games = _filteredGames;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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

// ── Private helpers ────────────────────────────────────────────────────────────

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
        color:        AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          ),
        ],
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
            style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 10),
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
      color:      AppColors.onSurface,
      fontSize:   16,
      fontWeight: FontWeight.bold,
    ),
  );
}
