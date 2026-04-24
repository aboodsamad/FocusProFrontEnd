import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

enum NavTab { home, games, rooms, coach, habits, profile }

class AppBottomNav extends StatelessWidget {
  final NavTab current;
  const AppBottomNav({super.key, required this.current});

  void _go(BuildContext context, NavTab tab) {
    if (tab == current) return;
    switch (tab) {
      case NavTab.home:
        Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
      case NavTab.games:
        Navigator.pushReplacementNamed(context, '/games');
      case NavTab.rooms:
        Navigator.pushReplacementNamed(context, '/rooms');
      case NavTab.coach:
        Navigator.pushReplacementNamed(context, '/coaching');
      case NavTab.habits:
        Navigator.pushReplacementNamed(context, '/habits');
      case NavTab.profile:
        Navigator.pushReplacementNamed(context, '/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -2),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.home_rounded,           label: 'Home',    selected: current == NavTab.home,    onTap: () => _go(context, NavTab.home)),
              _NavItem(icon: Icons.extension_outlined,     label: 'Games',   selected: current == NavTab.games,   onTap: () => _go(context, NavTab.games)),
              _NavItem(icon: Icons.groups_outlined,        label: 'Rooms',   selected: current == NavTab.rooms,   onTap: () => _go(context, NavTab.rooms)),
              _NavItem(icon: Icons.psychology_outlined,    label: 'Coach',   selected: current == NavTab.coach,   onTap: () => _go(context, NavTab.coach)),
              _NavItem(icon: Icons.task_alt_outlined,      label: 'Habits',  selected: current == NavTab.habits,  onTap: () => _go(context, NavTab.habits)),
              _NavItem(icon: Icons.person_outline_rounded, label: 'Profile', selected: current == NavTab.profile, onTap: () => _go(context, NavTab.profile)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : AppColors.onSurfaceVariant,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.primary : AppColors.onSurfaceVariant,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
