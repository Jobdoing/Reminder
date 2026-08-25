import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:reminder/models/memory_record.dart';

// Legacy adapter that writes only the original 4 fields (simulates old on-disk data).
class _LegacyMemoryRecordAdapter extends TypeAdapter<MemoryRecord> {
  @override
  final int typeId = 0;

  @override
  MemoryRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MemoryRecord(
      id: fields[0] as String,
      photoPath: fields[1] as String,
      text: fields[2] as String,
      createdAt: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, MemoryRecord obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.photoPath)
      ..writeByte(2)
      ..write(obj.text)
      ..writeByte(3)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _LegacyMemoryRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

void main() {
  test('MemoryRecord holds photo and text separately', () {
    final now = DateTime(2026, 8, 24, 10, 30);
    final r = MemoryRecord(
      id: 'abc',
      photoPath: '/tmp/photo.jpg',
      text: '明天下午去看王醫師',
      createdAt: now,
    );
    expect(r.id, 'abc');
    expect(r.photoPath, '/tmp/photo.jpg');
    expect(r.text, '明天下午去看王醫師');
    expect(r.createdAt, now);
  });

  test('new record round-trips all fields', () {
    final r = MemoryRecord(
      id: '1',
      photoPath: '/p.jpg',
      text: 't',
      createdAt: DateTime(2026, 1, 1),
      isReminder: true,
      reminderAt: DateTime(2026, 1, 2, 9),
      intent: 'visit',
      mentionedContacts: const ['王醫師'],
    );
    expect(r.isReminder, true);
    expect(r.intent, 'visit');
    expect(r.mentionedContacts, ['王醫師']);
  });

  test(
    'adapter reads a legacy 4-field record (no reminder fields) without throwing',
    () async {
      // Write the record using the legacy 4-field adapter, then read back with
      // the new 8-field adapter. This genuinely exercises the null-guard paths in
      // the generated read() for fields[4..7].
      final tmp = await Directory.systemTemp.createTemp('hive_compat_test');
      try {
        // Phase 1: write with legacy adapter (4 fields only).
        Hive.init(tmp.path);
        Hive.registerAdapter(_LegacyMemoryRecordAdapter(), override: true);
        final writeBox = await Hive.openBox<MemoryRecord>('legacy');
        await writeBox.put(
          'rec1',
          MemoryRecord(
            id: 'rec1',
            photoPath: '/p.jpg',
            text: 't',
            createdAt: DateTime(2026, 1, 1),
          ),
        );
        await writeBox.close();

        // Phase 2: re-open with the new adapter (8 fields, null-guarded).
        // Reset Hive so it picks up the new adapter.
        await Hive.close();
        Hive.init(tmp.path);
        Hive.registerAdapter(MemoryRecordAdapter(), override: true);
        final readBox = await Hive.openBox<MemoryRecord>('legacy');
        final r = readBox.get('rec1')!;

        expect(r.isReminder, false);
        expect(r.intent, 'record');
        expect(r.mentionedContacts, isEmpty);

        await readBox.close();
      } finally {
        await Hive.close();
        tmp.deleteSync(recursive: true);
      }
    },
  );
}
