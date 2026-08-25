import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminder/models/memory_record.dart';
import 'package:reminder/screens/record_detail_screen.dart';
import 'package:reminder/screens/photo_view_screen.dart';
import 'package:reminder/services/photo_store.dart';

void main() {
  late Directory documents;

  setUp(() {
    documents = Directory.systemTemp.createTempSync('record_detail_documents');
    PhotoStore.init(documents);
  });

  tearDown(() {
    documents.deleteSync(recursive: true);
  });

  testWidgets('edits text and calls onEdit with new value', (tester) async {
    String? edited;
    final record = MemoryRecord(
      id: 'a',
      photoPath: '',
      text: '吃藥',
      createdAt: DateTime(2026, 8, 24),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RecordDetailScreen(
          record: record,
          onEdit: (t) async => edited = t,
          onDelete: () async {},
        ),
      ),
    );

    await tester.tap(find.text('修改文字'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '吃藥（飯後）');
    await tester.tap(find.text('存'));
    await tester.pumpAndSettle();

    expect(edited, '吃藥（飯後）');
  });

  testWidgets('delete requires confirmation before calling onDelete', (
    tester,
  ) async {
    var deleted = false;
    final record = MemoryRecord(
      id: 'a',
      photoPath: '',
      text: '吃藥',
      createdAt: DateTime(2026, 8, 24),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RecordDetailScreen(
          record: record,
          onEdit: (_) async {},
          onDelete: () async => deleted = true,
        ),
      ),
    );
    await tester.tap(find.text('刪除'));
    await tester.pumpAndSettle();
    expect(deleted, isFalse);
    expect(find.text('照片、文字和這筆提醒都會刪除。'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, '刪除'),
      ),
    );
    await tester.pumpAndSettle();
    expect(deleted, isTrue);
  });

  testWidgets('delete cancellation keeps the record', (tester) async {
    var deleted = false;
    final record = MemoryRecord(
      id: 'a',
      photoPath: '',
      text: '吃藥',
      createdAt: DateTime(2026, 8, 24),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RecordDetailScreen(
          record: record,
          onEdit: (_) async {},
          onDelete: () async => deleted = true,
        ),
      ),
    );

    await tester.tap(find.text('刪除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();

    expect(deleted, isFalse);
  });

  testWidgets('tapping the photo opens the zoomable photo view', (
    tester,
  ) async {
    // Minimal valid 1x1 PNG so File(...).existsSync() is true and the
    // photo block renders (content sniffed by decoder, .jpg name is fine).
    // Use sync I/O: async dart:io calls (createTemp) hang in Flutter test env.
    File('${documents.path}/memory_photos/p.jpg')
      ..createSync(recursive: true)
      ..writeAsBytesSync(<int>[
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x49,
        0x48,
        0x44,
        0x52,
        0x00,
        0x00,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x01,
        0x08,
        0x06,
        0x00,
        0x00,
        0x00,
        0x1F,
        0x15,
        0xC4,
        0x89,
        0x00,
        0x00,
        0x00,
        0x0A,
        0x49,
        0x44,
        0x41,
        0x54,
        0x78,
        0x9C,
        0x63,
        0x00,
        0x01,
        0x00,
        0x00,
        0x05,
        0x00,
        0x01,
        0x0D,
        0x0A,
        0x2D,
        0xB4,
        0x00,
        0x00,
        0x00,
        0x00,
        0x49,
        0x45,
        0x4E,
        0x44,
        0xAE,
        0x42,
        0x60,
        0x82,
      ]);
    final record = MemoryRecord(
      id: 'a',
      photoPath: 'memory_photos/p.jpg',
      text: '吃藥',
      createdAt: DateTime(2026, 8, 24),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RecordDetailScreen(
          record: record,
          onEdit: (_) async {},
          onDelete: () async {},
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('detailPhoto')));
    await tester.pumpAndSettle();

    expect(find.byType(PhotoViewScreen), findsOneWidget);
  });
}
