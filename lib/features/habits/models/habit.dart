import 'package:flutter/material.dart';

class Habit {
  final int? id;
  final String title;
  final String? description;
  final int durationMinutes;
  final int frequencyPerWeek;
  final bool monday;
  final bool tuesday;
  final bool wednesday;
  final bool thursday;
  final bool friday;
  final bool saturday;
  final bool sunday;
  // Computed by backend from habit_logs
  final bool doneToday;
  final int streak;
  // UI-only fields (stored locally, not in DB)
  final String iconName;
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

  /// Returns [Mon, Tue, Wed, Thu, Fri, Sat, Sun] as a list for UI rendering.
  List<bool> get days =>
      [monday, tuesday, wednesday, thursday, friday, saturday, sunday];

  const Habit({
    this.id,
    required this.title,
    this.description,
    this.durationMinutes = 10,
    this.frequencyPerWeek = 1,
    this.monday = false,
    this.tuesday = false,
    this.wednesday = false,
    this.thursday = false,
    this.friday = false,
    this.saturday = false,
    this.sunday = false,
    this.doneToday = false,
    this.streak = 0,
    this.iconName = 'star',
    this.category = 'general',
  });

  Habit copyWith({
    int? id,
    String? title,
    String? description,
    int? durationMinutes,
    int? frequencyPerWeek,
    bool? monday,
    bool? tuesday,
    bool? wednesday,
    bool? thursday,
    bool? friday,
    bool? saturday,
    bool? sunday,
    bool? doneToday,
    int? streak,
    String? iconName,
    String? category,
  }) =>
      Habit(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        frequencyPerWeek: frequencyPerWeek ?? this.frequencyPerWeek,
        monday: monday ?? this.monday,
        tuesday: tuesday ?? this.tuesday,
        wednesday: wednesday ?? this.wednesday,
        thursday: thursday ?? this.thursday,
        friday: friday ?? this.friday,
        saturday: saturday ?? this.saturday,
        sunday: sunday ?? this.sunday,
        doneToday: doneToday ?? this.doneToday,
        streak: streak ?? this.streak,
        iconName: iconName ?? this.iconName,
        category: category ?? this.category,
      );

  /// Deserialize from backend JSON (Spring Boot returns camelCase).
  /// `doneToday` and `streak` are computed by the backend from habit_logs.
  /// `iconName` and `category` are local UI prefs that may be echoed back
  /// from local storage merging.
  factory Habit.fromJson(Map<String, dynamic> json) => Habit(
        id: json['id'] as int?,
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString(),
        durationMinutes: (json['durationMinutes'] ?? json['duration_minutes'] ?? 10) as int,
        frequencyPerWeek: (json['frequencyPerWeek'] ?? json['frequency_per_week'] ?? 1) as int,
        monday: (json['monday'] ?? false) as bool,
        tuesday: (json['tuesday'] ?? false) as bool,
        wednesday: (json['wednesday'] ?? false) as bool,
        thursday: (json['thursday'] ?? false) as bool,
        friday: (json['friday'] ?? false) as bool,
        saturday: (json['saturday'] ?? false) as bool,
        sunday: (json['sunday'] ?? false) as bool,
        doneToday: (json['doneToday'] ?? json['done_today'] ?? false) as bool,
        streak: (json['streak'] ?? 0) as int,
        iconName: json['iconName']?.toString() ?? 'star',
        category: json['category']?.toString() ?? 'general',
      );

  /// Full JSON for local storage (preserves UI-only fields).
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'title': title,
        if (description != null) 'description': description,
        'durationMinutes': durationMinutes,
        'frequencyPerWeek': frequencyPerWeek,
        'monday': monday,
        'tuesday': tuesday,
        'wednesday': wednesday,
        'thursday': thursday,
        'friday': friday,
        'saturday': saturday,
        'sunday': sunday,
        'doneToday': doneToday,
        'streak': streak,
        'iconName': iconName,
        'category': category,
      };

  /// API body for POST /habits and PUT /habits/{id}.
  /// Only includes fields that exist in the habits DB table.
  Map<String, dynamic> toApiJson() => {
        'title': title,
        if (description != null && description!.isNotEmpty)
          'description': description,
        'durationMinutes': durationMinutes,
        'frequencyPerWeek': frequencyPerWeek,
        'monday': monday,
        'tuesday': tuesday,
        'wednesday': wednesday,
        'thursday': thursday,
        'friday': friday,
        'saturday': saturday,
        'sunday': sunday,
      };
}
