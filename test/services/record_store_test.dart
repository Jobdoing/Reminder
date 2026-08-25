import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:reminder/models/memory_record.dart';
import 'package:reminder/services/photo_store.dart';
import 'package:reminder/services/record_store.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('recordstore');
    Hive.init(tmp.path);
    PhotoStore.init(tmp);
    await RecordStore.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tmp.delete(recursive: true);
  });

  test('save then getAll returns newest first', () async {
    await RecordStore.save(
      MemoryRecord(
        id: 'a',
        photoPath: '',
        text: 'first',
        createdAt: DateTime(2026, 8, 20),
      ),
    );
    await RecordStore.save(
      MemoryRecord(
        id: 'b',
        photoPath: '',
        text: 'second',
        createdAt: DateTime(2026, 8, 24),
      ),
    );

    final all = RecordStore.getAll();
    expect(all.map((r) => r.id).toList(), ['b', 'a']);
  });

  test('delete removes record and its photo file', () async {
    final photo = File('${tmp.path}/memory_photos/p.jpg')
      ..createSync(recursive: true)
      ..writeAsBytesSync([1]);
    await RecordStore.save(
      MemoryRecord(
        id: 'a',
        photoPath: 'memory_photos/p.jpg',
        text: 't',
        createdAt: DateTime(2026, 8, 24),
      ),
    );

    await RecordStore.delete('a');

    expect(RecordStore.get('a'), isNull);
    expect(photo.existsSync(), isFalse);
  });

  test('init migrates a legacy app-container photo path', () async {
    const legacy = '/old/app/container/Documents/memory_photos/p.jpg';
    await RecordStore.save(
      MemoryRecord(
        id: 'a',
        photoPath: legacy,
        text: 't',
        createdAt: DateTime(2026, 8, 24),
      ),
    );
    await Hive.box<MemoryRecord>('memory_records').close();

    await RecordStore.init();

    expect(RecordStore.get('a')!.photoPath, 'memory_photos/p.jpg');
  });

  test(
    'delete keeps the record when its stored photo path is invalid',
    () async {
      await RecordStore.save(
        MemoryRecord(
          id: 'a',
          photoPath: '${tmp.path}/outside.jpg',
          text: 't',
          createdAt: DateTime(2026, 8, 24),
        ),
      );

      await expectLater(RecordStore.delete('a'), throwsArgumentError);

      expect(RecordStore.get('a'), isNotNull);
    },
  );
}
