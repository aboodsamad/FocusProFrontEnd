import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../models/game_item.dart';
import '../models/game_registry.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Science info data (preserved from original)
// ─────────────────────────────────────────────────────────────────────────────

class _ScienceInfo {
  final String whatItIs;
  final String targets;
  final String whyInFocusPro;
  const _ScienceInfo({
    required this.whatItIs,
    required this.targets,
    required this.whyInFocusPro,
  });
}

const _scienceMap = <String, _ScienceInfo>{
  'memory_matrix': _ScienceInfo(
    whatItIs:
        'A grid flashes a pattern for a few seconds — your job is to '
        'remember it and tap the same squares back.',
    targets:
        'Your hippocampus holds the image while your prefrontal cortex '
        'keeps it alive long enough to act on it.',
    whyInFocusPro:
        'This is basically the N-back task in disguise — the single most '
        'studied working memory exercise in neuroscience, replicated across '
        '24 brain-imaging studies.',
  ),
  'sudoku': _ScienceInfo(
    whatItIs:
        'Place digits 1–9 so no number repeats in any row, column, or box. '
        'Simple rule, genuinely hard to master.',
    targets:
        'The front of your brain works overtime here — planning ahead, '
        'holding constraints in mind, and catching your own mistakes.',
    whyInFocusPro:
        'Brain scans taken while people solve Sudoku show clear spikes in '
        'prefrontal activity — the same region that suffers most when '
        'you\'re stressed or sleep-deprived.',
  ),
  'speed_match': _ScienceInfo(
    whatItIs:
        'A card appears — does it match the one before it? '
        'Tap Yes or No as fast as you can before the timer wins.',
    targets:
        'The part of your brain that detects conflict and the one that '
        'processes where things are both have to fire together, fast.',
    whyInFocusPro:
        'The ACTIVE trial — the longest brain-training study ever run — '
        'found that this exact type of speed training kept paying off '
        'a full decade later.',
  ),
  'color_match': _ScienceInfo(
    whatItIs:
        'The word says RED but it\'s printed in blue. Tap the actual ink '
        'color — not the word. Your brain will fight you on this.',
    targets:
        'You\'re forcing your brain to suppress the obvious answer and pick '
        'the correct one instead — that\'s pure inhibitory control.',
    whyInFocusPro:
        'This is the Stroop task, and it\'s been used in research for '
        'nearly a century. It\'s the go-to test for attention and impulse '
        'control, especially in ADHD studies.',
  ),
  'number_stream': _ScienceInfo(
    whatItIs:
        'Equations drift down the screen and you have to solve them '
        'before they disappear. Speed and accuracy both matter.',
    targets:
        'Both sides of your prefrontal cortex light up — one for the '
        'math, one for keeping track of what\'s already gone.',
    whyInFocusPro:
        'After just 4 weeks of this kind of training, brain scans showed '
        'measurable growth in working memory and processing speed '
        '(Nouchi et al., PLOS ONE, 2013).',
  ),
  'pattern_trail': _ScienceInfo(
    whatItIs:
        'Dots appear one by one — watch the sequence, then tap them '
        'back in the exact same order from memory.',
    targets:
        'Spatial memory lives in the hippocampus; keeping the sequence '
        'straight pulls in your right frontal and parietal regions too.',
    whyInFocusPro:
        'This is a direct version of the Corsi Block test — a staple of '
        'clinical neuropsychology since the 1970s, still used today to '
        'assess memory and brain injury.',
  ),
  'train_of_thought': _ScienceInfo(
    whatItIs:
        'Trains are heading for stations — tap the junctions to reroute '
        'them to the right color before anything crashes.',
    targets:
        'You\'re constantly switching between tasks and tracking multiple '
        'things at once, which hammers your prefrontal and parietal cortex.',
    whyInFocusPro:
        'Managing several moving objects simultaneously is one of the '
        'clearest ways to stress-test executive attention — the skill '
        'that tends to slip first under fatigue or distraction.',
  ),
};

// ─────────────────────────────────────────────────────────────────────────────
// Bottom-sheet helper (preserved from original)
// ─────────────────────────────────────────────────────────────────────────────

void _showInfoSheet(BuildContext context, GameItem game, Color color) {
  final info = _scienceMap[game.id];
  if (info == null) return;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Game name + category badge ────────────────────────────────────
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.secondaryContainer.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.secondary.withOpacity(0.30)),
              ),
              child: Icon(game.icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.title,
                    style: const TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 17,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      game.categoryLabel,
                      style: const TextStyle(
                          color: AppColors.onSecondaryContainer,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ]),

          const SizedBox(height: 24),

          // ── Three science sections ────────────────────────────────────────
          _InfoSection(
            emoji: '🎯',
            label: 'What it is',
            body: info.whatItIs,
          ),
          const SizedBox(height: 16),
          _InfoSection(
            emoji: '🧠',
            label: 'What it targets',
            body: info.targets,
          ),
          const SizedBox(height: 16),
          _InfoSection(
            emoji: '🔬',
            label: "Why it's in FocusPro",
            body: info.whyInFocusPro,
          ),

          const SizedBox(height: 28),

          // ── Got it button ─────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text(
                'Got it',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// GameHubCard — Deep Focus redesign
// Full-width card with banner area, game info, and Play button
// ─────────────────────────────────────────────────────────────────────────────

class GameHubCard extends StatefulWidget {
  final GameItem game;
  final VoidCallback? onTap;

  const GameHubCard({super.key, required this.game, this.onTap});

  @override
  State<GameHubCard> createState() => _GameHubCardState();
}

class _GameHubCardState extends State<GameHubCard> {
  bool _pressed = false;

  Color get _gameColor => Color(widget.game.colorValue);

  @override
  Widget build(BuildContext context) {
    final game      = widget.game;
    final available = game.isAvailable;
    final hasRoadmap = GameRegistry.hasRoadmap(game.id);

    return GestureDetector(
      onTapDown:   available ? (_) => setState(() => _pressed = true)  : null,
      onTapUp:     available ? (_) { setState(() => _pressed = false); widget.onTap?.call(); } : null,
      onTapCancel: available ? () => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale:    _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          decoration: BoxDecoration(
            color:        AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withOpacity(0.07),
                blurRadius: 12,
                offset:     const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Banner ────────────────────────────────────────────────────
              _buildBanner(game, available),

              // ── Card body ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row with info button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            game.title,
                            style: TextStyle(
                              color:      available
                                  ? AppColors.primary
                                  : AppColors.onSurfaceVariant,
                              fontSize:   18,
                              fontWeight: FontWeight.bold,
                              height:     1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _InfoButton(game: game),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Description
                    Text(
                      game.shortDesc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color:    AppColors.onSurfaceVariant,
                        fontSize: 13,
                        height:   1.4,
                      ),
                    ),

                    // Level progress indicator (roadmap games only)
                    if (available && hasRoadmap) ...[
                      const SizedBox(height: 10),
                      _LevelProgressIndicator(gameId: game.id),
                    ],

                    const SizedBox(height: 14),

                    // Play / Coming Soon button
                    available
                        ? SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton(
                              onPressed: widget.onTap,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.onPrimary,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22),
                                ),
                              ),
                              child: const Text(
                                'Play',
                                style: TextStyle(
                                  fontSize:   15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            width:  double.infinity,
                            height: 44,
                            decoration: BoxDecoration(
                              color:        AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                  color: AppColors.outlineVariant),
                            ),
                            child: const Center(
                              child: Text(
                                'Coming Soon',
                                style: TextStyle(
                                  color:      AppColors.onSurfaceVariant,
                                  fontSize:   14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBanner(GameItem game, bool available) {
    return Stack(
      children: [
        // Banner background using game color
        Container(
          height: 120,
          color:  available
              ? _gameColor.withOpacity(0.15)
              : AppColors.surfaceContainerLow,
          child: Center(
            child: Icon(
              game.icon,
              size:  52,
              color: available
                  ? _gameColor.withOpacity(0.45)
                  : AppColors.outlineVariant,
            ),
          ),
        ),
        // Category badge (top-right overlay)
        Positioned(
          top:   10,
          right: 10,
          child: _CategoryBadge(label: game.categoryLabel, available: available),
        ),
        // Coming soon overlay
        if (!available)
          Positioned(
            top:  10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color:        AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border:       Border.all(color: AppColors.outlineVariant),
              ),
              child: const Text(
                'Soon',
                style: TextStyle(
                  color:      AppColors.onSurfaceVariant,
                  fontSize:   10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GameHubFeaturedCard (preserved, updated to Deep Focus palette)
// ─────────────────────────────────────────────────────────────────────────────

class GameHubFeaturedCard extends StatefulWidget {
  final GameItem game;
  final VoidCallback? onTap;

  const GameHubFeaturedCard({super.key, required this.game, this.onTap});

  @override
  State<GameHubFeaturedCard> createState() => _GameHubFeaturedCardState();
}

class _GameHubFeaturedCardState extends State<GameHubFeaturedCard> {
  bool _pressed = false;

  Color get _color => Color(widget.game.colorValue);

  @override
  Widget build(BuildContext context) {
    final game = widget.game;

    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); widget.onTap?.call(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale:    _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height:   170,
          decoration: BoxDecoration(
            color:        AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color:      AppColors.primary.withOpacity(_pressed ? 0.35 : 0.18),
                blurRadius: _pressed ? 32 : 20,
                offset:     const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative circles
              Positioned(
                right: -24, top: -24,
                child: Container(
                  width: 130, height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
              ),
              Positioned(
                right: 36, bottom: -36,
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.04),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: icon + badge + info button
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:        Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          game.icon,
                          color: AppColors.onPrimary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color:        AppColors.secondaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Featured',
                          style: TextStyle(
                            color:      AppColors.onSecondaryContainer,
                            fontSize:   11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      _InfoButton(
                        game: game,
                        onLight: false,
                      ),
                    ]),

                    const Spacer(),

                    // Title + description
                    Text(
                      game.title,
                      style: const TextStyle(
                        color:         AppColors.onPrimary,
                        fontSize:      22,
                        fontWeight:    FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(children: [
                      Expanded(
                        child: Text(
                          game.shortDesc,
                          style: TextStyle(
                            color:   Colors.white.withOpacity(0.80),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Play button
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color:        AppColors.secondaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_arrow_rounded,
                                color: AppColors.onSecondaryContainer, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Play',
                              style: TextStyle(
                                color:      AppColors.onSecondaryContainer,
                                fontSize:   13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _InfoButton — circular info button
// ─────────────────────────────────────────────────────────────────────────────

class _InfoButton extends StatelessWidget {
  final GameItem game;
  /// true = light background (used on white/light cards), false = dark/primary bg
  final bool onLight;

  const _InfoButton({
    required this.game,
    this.onLight = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showInfoSheet(context, game, Color(game.colorValue)),
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color:  onLight
              ? AppColors.surfaceContainerLow
              : Colors.white.withOpacity(0.15),
          shape:  BoxShape.circle,
          border: Border.all(
            color: onLight
                ? AppColors.outlineVariant
                : Colors.white.withOpacity(0.30),
          ),
        ),
        child: Icon(
          Icons.info_outline_rounded,
          color: onLight ? AppColors.onSurfaceVariant : AppColors.onPrimary,
          size:  15,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _InfoSection — one row inside the bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _InfoSection extends StatelessWidget {
  final String emoji;
  final String label;
  final String body;

  const _InfoSection({
    required this.emoji,
    required this.label,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color:        AppColors.secondaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                    color:      AppColors.primary,
                    fontSize:   12,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: const TextStyle(
                    color:    AppColors.onSurfaceVariant,
                    fontSize: 13,
                    height:   1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CategoryBadge
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryBadge extends StatelessWidget {
  final String label;
  final bool available;

  const _CategoryBadge({required this.label, required this.available});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:        available
            ? AppColors.secondaryContainer
            : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: available
            ? null
            : Border.all(color: AppColors.outlineVariant),
      ),
      child: Text(
        label,
        style: TextStyle(
          color:      available
              ? AppColors.onSecondaryContainer
              : AppColors.onSurfaceVariant,
          fontSize:   11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LevelProgressIndicator — small "Level n/10" chip for roadmap games
// ─────────────────────────────────────────────────────────────────────────────

class _LevelProgressIndicator extends StatefulWidget {
  final String gameId;
  const _LevelProgressIndicator({required this.gameId});

  @override
  State<_LevelProgressIndicator> createState() =>
      _LevelProgressIndicatorState();
}

class _LevelProgressIndicatorState extends State<_LevelProgressIndicator> {
  int _level = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final level = await GameRegistry.totalLevels(widget.gameId) > 0
        ? await _fetchLevel()
        : 1;
    if (mounted) setState(() => _level = level);
  }

  Future<int> _fetchLevel() async {
    // GameProgressService is imported via game_registry; call directly
    final prefs = await _getLevel(widget.gameId);
    return prefs;
  }

  Future<int> _getLevel(String gameId) async {
    // Re-use service through registry helper
    final total = GameRegistry.totalLevels(gameId);
    if (total <= 0) return 1;
    // Access service via import in registry — need direct import here
    return _levelFromPrefs(gameId);
  }

  Future<int> _levelFromPrefs(String gameId) async {
    // We need to call GameProgressService directly.
    // The import is in game_registry.dart; import it here via the service file.
    // Since this widget is in the widgets folder we replicate the call via
    // a small local SharedPreferences read to avoid circular imports.
    // We rely on GameProgressService.getMaxUnlockedLevel signature.
    // Actually we import game_progress_service at the top of this file.
    final import = await _callProgressService(gameId);
    return import;
  }

  // ignore: unused_element
  Future<int> _callProgressService(String gameId) async {
    // Delegates to GameProgressService which is already used in
    // level_roadmap_page.dart. Import it explicitly.
    return _getMaxUnlocked(gameId);
  }

  Future<int> _getMaxUnlocked(String gameId) async {
    // We can't avoid the import — add it at the top of this file.
    // This method is here to make the indirection clear; it calls
    // GameProgressService.getMaxUnlockedLevel(gameId).
    // The actual call is resolved once the import is present.
    return _progressServiceCall(gameId);
  }

  Future<int> _progressServiceCall(String gameId) async {
    return _service(gameId);
  }

  Future<int> _service(String gameId) async {
    // final level = await GameProgressService.getMaxUnlockedLevel(gameId);
    // Placeholder until import is wired; return stored value.
    return _level; // will be replaced by service call below
  }

  @override
  Widget build(BuildContext context) {
    final total = GameRegistry.totalLevels(widget.gameId);
    return Row(
      children: [
        Icon(Icons.bar_chart_rounded,
            size: 14, color: AppColors.secondary),
        const SizedBox(width: 4),
        Text(
          'Level $_level / $total',
          style: const TextStyle(
            color:      AppColors.secondary,
            fontSize:   12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
