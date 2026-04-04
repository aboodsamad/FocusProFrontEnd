import 'package:flutter/material.dart';

class Habit {
  final int? id;
  final String title;
  final String iconName;
  final bool doneToday;
  final int streak;
  final String category;

  static IconData iconForName(String name) {
    switch (name) {
      case 'menu_book':   return Icons.menu_book_outlined;
      case 'videogame':   return Icons.videogame_asset_outlined;
      case 'phone_off':   return Icons.phone_android_outlined;
      case 'fitness':     return Icons.fitness_center_outlined;
      case 'water':       return Icons.water_drop_outlined;
      case 'meditation':  return Icons.self_improvement_outlined;
      case 'sleep':       return Icons.bedtime_outlined;
      case 'run':         return Icons.directions_run_outlined;
      case 'music':       return Icons.music_note_outlined;
      case 'journal':     return Icons.edit_note_outlined;
      case 'timer':       return Icons.timer_outlined;
      case 'brain':       return Icons.psychology_outlined;
      case 'no_phone':    return Icons.phone_locked_outlined;
      case 'food':        return Icons.restaurant_outlined;
      case 'walk':        return Icons.directions_walk_outlined;
      case 'sun':         return Icons.wb_sunny_outlined;
      case 'heart':       return Icons.favorite_outline;
      default:            return Icons.star_outline;
    }
  }

  IconData get icon => iconForName(iconName);

  const Habit({
    this.id,
    required this.title,
    required this.iconName,
    this.doneToday = false,
    this.streak = 0,
    this.category = 'general',
  });

  Habit copyWith({
    int? id,
    String? title,
    String? iconName,
    bool? doneToday,
    int? streak,
    String? category,
  }) =>
      Habit(
        id: id ?? this.id,
        title: title ?? this.title,
        iconName: iconName ?? this.iconName,
        doneToday: doneToday ?? this.doneToday,
        streak: streak ?? this.streak,
        category: category ?? this.category,
      );

  factory Habit.fromJson(Map<String, dynamic> json) => Habit(
        id: json['id'] as int?,
        title: json['title']?.toString() ?? '',
        iconName: json['iconName']?.toString() ?? 'star',
        doneToday: json['doneToday'] as bool? ?? false,
        streak: json['streak'] as int? ?? 0,
        category: json['category']?.toString() ?? 'general',
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'title': title,
        'iconName': iconName,
        'doneToday': doneToday,
        'streak': streak,
        'category': category,
      };
}
