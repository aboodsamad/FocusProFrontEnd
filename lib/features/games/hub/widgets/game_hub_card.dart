import 'package:flutter/material.dart';

import '../models/game_item.dart';

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
      onTapDown:  available ? (_) => setState(() => _pressed = true)  : null,
      onTapUp:    available ? (_) { setState(() => _pressed = false); widget.onTap?.call(); } : null,
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
                // ── Icon row + coming-soon badge ──────────────────────────
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
                    if (!available) _ComingSoonBadge(),
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
                    // Top row: icon + badge
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
