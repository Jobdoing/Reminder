import 'package:hive_flutter/hive_flutter.dart';

import '../semantic/note_analysis.dart';

/// Hive-backed per-part-of-day reminder time. Stores the user's last-used time
/// for each [DayPart]; falls back to a sensible default when none is learned.
/// Box name: 'part_of_day', one key per part (the enum name), value = minutes
/// since midnight.
class PartOfDayStore {
  static const _boxName = 'part_of_day';

  // Default time per part-of-day (hour, minute) when nothing is learned yet.
  static const Map<DayPart, (int, int)> _defaults = {
    DayPart.morning: (8, 0),
    DayPart.noon: (12, 0),
    DayPart.afternoon: (14, 0),
    DayPart.dusk: (17, 0),
    DayPart.evening: (20, 0),
  };

  static Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
  }

  static Box get _box => Hive.box(_boxName);

  /// The learned time for [part], or its default if none stored / box not open.
  static (int, int) timeFor(DayPart part) {
    final fallback = _defaults[part]!;
    if (!Hive.isBoxOpen(_boxName)) return fallback;
    final v = _box.get(part.name);
    if (v is int) return (v ~/ 60, v % 60);
    return fallback;
  }

  /// Remember [hour]:[minute] as the user's time for [part].
  static Future<void> setTimeFor(DayPart part, int hour, int minute) async {
    await _box.put(part.name, hour * 60 + minute);
  }
}
