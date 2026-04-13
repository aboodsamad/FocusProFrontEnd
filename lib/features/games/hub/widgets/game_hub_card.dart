import 'package:flutter/material.dart';

import '../models/game_item.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Science info data
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
    whatItIs: 'A grid lights up a pattern you must recreate from memory.',
    targets: 'Hippocampus + DLPFC (working memory, spatial recall).',
    whyInFocusPro:
        'Based on the N-back task — the most replicated working memory paradigm '
        'in neuroscience, confirmed across 24 fMRI studies.',
  ),
  'sudoku': _ScienceInfo(
    whatItIs: 'Fill every row, column and box with digits 1–9 with no repeats.',
    targets:
        'DLPFC + Medial PFC + Anterior Cingulate Cortex '
        '(logical reasoning, executive control).',
    whyInFocusPro:
        'Direct fNIRS neuroimaging studies confirmed PFC activation during '
        'Sudoku rule-based reasoning (Frontiers in Neuroimaging, 2024).',
  ),
  'speed_match': _ScienceInfo(
    whatItIs:
        'Does this card match the previous one? Tap YES or NO before time runs out.',
    targets:
        'Anterior Cingulate Cortex + Inferior Parietal Lobe '
        '(processing speed, rapid decision-making).',
    whyInFocusPro:
        'Speed-of-processing training showed benefits lasting 10 years in the '
        'ACTIVE trial — the longest brain training RCT ever conducted.',
  ),
  'color_match': _ScienceInfo(
    whatItIs: 'Tap the ink color of the word, not what the word says.',
    targets:
        'ACC + DLPFC + Right Inferior Frontal Cortex '
        '(selective attention, inhibitory control).',
    whyInFocusPro:
        'The Stroop task is the gold standard for measuring attention inhibition, '
        'especially in ADHD research, with 3,000+ citations.',
  ),
  'number_stream': _ScienceInfo(
    whatItIs: 'Solve falling equations before they hit the bottom.',
    targets:
        'Bilateral DLPFC + Intraparietal Sulcus '
        '(arithmetic processing, working memory).',
    whyInFocusPro:
        'A double-blind RCT using NIRS confirmed bilateral DLPFC activation after '
        '4 weeks of calculation-based training (Nouchi et al., PLOS ONE, 2013).',
  ),
  'pattern_trail': _ScienceInfo(
    whatItIs:
        'Watch dots light up in sequence, then tap them back in the same order.',
    targets:
        'Hippocampus + Right Frontal + Parietal Cortex '
        '(visuospatial working memory, sequence memory).',
    whyInFocusPro:
        'Direct implementation of the Corsi Block task — a validated clinical '
        'neuropsychological test used since the 1970s.',
  ),
  'train_of_thought': _ScienceInfo(
    whatItIs:
        'Route trains to matching colored stations by tapping junctions to '
        'switch tracks before they collide.',
    targets:
        'ACC + DLPFC + Posterior Parietal Cortex '
        '(multitasking, task-switching, selective attention).',
    whyInFocusPro:
        'Simultaneous multi-object tracking paradigms activate fronto-parietal '
        'executive networks — a key clinical marker of attention capacity and '
        'executive control.',
  ),
};

// ─────────────────────────────────────────────────────────────────────────────
// Bottom-sheet helper
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
        color: Color(0xFF0F1624),
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
                color: Colors.white24,
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
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.30)),
              ),
              child: Icon(game.icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      game.categoryLabel,
                      style: TextStyle(
                          color: color,
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
            color: color,
          ),
          const SizedBox(height: 16),
          _InfoSection(
            emoji: '🧠',
            label: 'What it targets',
            body: info.targets,
            color: color,
          ),
          const SizedBox(height: 16),
          _InfoSection(
            emoji: '🔬',
            label: "Why it's in FocusPro",
            body: info.whyInFocusPro,
            color: color,
          ),

          const SizedBox(height: 28),

          // ── Got it button ─────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.40)),
                ),
                child: Center(
                  child: Text(
                    'Got it',
                    style: TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight: FontWeight.bold),
                  ),
                ),
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
// GameHubCard
// ─────────────────────────────────────────────────────────────────────────────

/// Card shown in the 2-column grid on [GamesHubPage].
/// Tapping an available game fires [onTap]; coming-soon cards show a badge.
class GameHubCard extends StatefulWidget {
  final GameItem game;
  final VoidCallback? onTap;

  const GameHubCard({super.key, required this.game, this.onTap});

  @override
  State<GameHubCard> createState() => _GameHubCardState();
}

class _GameHubCardState extends State<GameHubCard> {
  bool _pressed = false;

  Color get _color => Color(widget.game.colorValue);

  @override
  Widget build(BuildContext context) {
    final game      = widget.game;
    final available = game.isAvailable;

    return GestureDetector(
      onTapDown:   available ? (_) => setState(() => _pressed = true)  : null,
      onTapUp:     available ? (_) { setState(() => _pressed = false); widget.onTap?.call(); } : null,
      onTapCancel: available ? () => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale:    _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve:    Curves.easeOut,
          decoration: BoxDecoration(
            color:        const Color(0xFF0F1624),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _pressed
                  ? _color.withOpacity(0.65)
                  : available
                      ? _color.withOpacity(0.22)
                      : Colors.white.withOpacity(0.06),
              width: _pressed ? 1.8 : 1.2,
            ),
            boxShadow: _pressed
                ? [BoxShadow(color: _color.withOpacity(0.28),
                    blurRadius: 22, spreadRadius: 2)]
                : [],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Icon row + badges ─────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color:        _color.withOpacity(available ? 0.14 : 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _color.withOpacity(available ? 0.28 : 0.1),
                        ),
                      ),
                      child: Icon(
                        widget.game.icon,
                        color: _color.withOpacity(available ? 1.0 : 0.4),
                        size: 24,
                      ),
                    ),
                    const Spacer(),
                    if (!available) ...[
                      _ComingSoonBadge(),
                      const SizedBox(width: 6),
                    ],
                    // ── Info button ───────────────────────────────────────
                    _InfoButton(game: game, color: _color),
                  ],
                ),

                const SizedBox(height: 14),

                // ── Title ─────────────────────────────────────────────────
                Text(
                  game.title,
                  style: TextStyle(
                    color:      available ? Colors.white : Colors.white38,
                    fontSize:   15,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                // ── Short description ─────────────────────────────────────
                Text(
                  game.shortDesc,
                  maxLines:  2,
                  overflow:  TextOverflow.ellipsis,
                  style: TextStyle(
                    color:   available
                        ? Colors.grey[500]
                        : Colors.white12,
                    fontSize: 11,
                    height:   1.4,
                  ),
                ),

                const Spacer(),

                // ── Footer: category + difficulty ─────────────────────────
                Row(
                  children: [
                    _Chip(
                      label: game.categoryLabel,
                      color: _color,
                      faded: !available,
                    ),
                    const SizedBox(width: 6),
                    _Chip(
                      label: game.difficultyLabel,
                      color: _difficultyColor(game.difficulty),
                      faded: !available,
                    ),
                    const Spacer(),
                    if (available)
                      Icon(Icons.arrow_forward_ios_rounded,
                          color: _color.withOpacity(0.5), size: 12),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _difficultyColor(GameDifficulty d) {
    switch (d) {
      case GameDifficulty.easy:   return const Color(0xFF10B981);
      case GameDifficulty.medium: return const Color(0xFFF97316);
      case GameDifficulty.hard:   return const Color(0xFFEF4444);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GameHubFeaturedCard
// ─────────────────────────────────────────────────────────────────────────────

/// Large hero card shown at the top of the hub for the featured/first game.
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
            gradient: LinearGradient(
              colors: [
                _color.withOpacity(_pressed ? 0.9 : 0.75),
                _color.withOpacity(0.35),
              ],
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _color.withOpacity(_pressed ? 0.7 : 0.45),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color:      _color.withOpacity(_pressed ? 0.35 : 0.22),
                blurRadius: _pressed ? 32 : 24,
                offset:     const Offset(0, 8),
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
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color:        Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '⚡ Featured',
                          style: TextStyle(
                            color:      Colors.white,
                            fontSize:   11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // ── Info button (white variant for colored bg) ────────
                      _InfoButton(
                        game: game,
                        color: Colors.white,
                        bgOpacity: 0.18,
                        borderOpacity: 0.35,
                      ),
                    ]),

                    const Spacer(),

                    // Title + description
                    Text(
                      game.title,
                      style: const TextStyle(
                        color:       Colors.white,
                        fontSize:    22,
                        fontWeight:  FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(children: [
                      Expanded(
                        child: Text(
                          game.shortDesc,
                          style: TextStyle(
                            color:   Colors.white.withOpacity(0.75),
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
                          color:        Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_arrow_rounded,
                                color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Play',
                              style: TextStyle(
                                color:      Colors.white,
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
// _InfoButton — 28×28 circular info button
// ─────────────────────────────────────────────────────────────────────────────

class _InfoButton extends StatelessWidget {
  final GameItem game;
  final Color    color;
  final double   bgOpacity;
  final double   borderOpacity;

  const _InfoButton({
    required this.game,
    required this.color,
    this.bgOpacity     = 0.12,
    this.borderOpacity = 0.30,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showInfoSheet(context, game, Color(game.colorValue)),
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color:  color.withOpacity(bgOpacity),
          shape:  BoxShape.circle,
          border: Border.all(color: color.withOpacity(borderOpacity)),
        ),
        child: Icon(
          Icons.info_outline_rounded,
          color: color,
          size:  14,
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
  final Color  color;

  const _InfoSection({
    required this.emoji,
    required this.label,
    required this.body,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color:        color.withOpacity(0.10),
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
                style: TextStyle(
                    color:      color,
                    fontSize:   12,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: const TextStyle(
                    color:    Colors.white70,
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
// Small private widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final Color  color;
  final bool   faded;

  const _Chip({required this.label, required this.color, required this.faded});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withOpacity(faded ? 0.04 : 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color:      color.withOpacity(faded ? 0.3 : 1.0),
          fontSize:   10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ComingSoonBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:        Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: const Text(
        'Soon',
        style: TextStyle(
          color:      Colors.white38,
          fontSize:   9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
