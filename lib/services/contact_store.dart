import 'package:hive_flutter/hive_flutter.dart';

/// Hive-backed store for contact names used by NameCorrector.
/// Box name: 'contacts', key: 'names' (List of String).
class ContactStore {
  static const _boxName = 'contacts';
  static const _keyNames = 'names';

  static Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  static Box get _box => Hive.box(_boxName);

  /// Returns stored names, or empty list if box is not open (safe in tests).
  static List<String> names() {
    if (!Hive.isBoxOpen(_boxName)) return const [];
    final v = _box.get(_keyNames);
    if (v is List) return List<String>.unmodifiable(v.cast<String>());
    return const [];
  }

  /// Trims, drops empties, deduplicates, then persists.
  static Future<void> setNames(List<String> input) async {
    final cleaned = input
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    await _box.put(_keyNames, cleaned);
  }
}
