import 'package:hive_flutter/hive_flutter.dart';

import '../models/memory_record.dart';
import 'photo_store.dart';

class RecordStore {
  static const _boxName = 'memory_records';

  static Future<void> init() async {
    final adapter = MemoryRecordAdapter();
    if (!Hive.isAdapterRegistered(adapter.typeId)) {
      Hive.registerAdapter(adapter);
    }
    final box = await Hive.openBox<MemoryRecord>(_boxName);
    for (final record in box.values) {
      final storedPath = PhotoStore.storagePath(record.photoPath);
      if (storedPath != record.photoPath) {
        record.photoPath = storedPath;
        await box.put(record.id, record);
      }
    }
  }

  static Box<MemoryRecord> get _box => Hive.box<MemoryRecord>(_boxName);

  static Future<void> save(MemoryRecord record) => _box.put(record.id, record);

  static MemoryRecord? get(String id) => _box.get(id);

  static List<MemoryRecord> getAll() =>
      _box.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  static Future<void> delete(String id) async {
    final record = _box.get(id);
    if (record == null) return;
    // NOTE(ceiling): Hive and the filesystem have no shared transaction.
    // Deleting the photo first preserves the record when file deletion fails;
    // a later Hive write failure can still leave a record without its photo.
    // Add a durable deletion journal if this occurs in practice.
    await PhotoStore.deleteStoredFile(record.photoPath);
    await _box.delete(id);
  }
}
