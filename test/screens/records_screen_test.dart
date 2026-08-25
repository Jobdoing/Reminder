import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminder/models/memory_record.dart';
import 'package:reminder/screens/records_screen.dart';

void main() {
  testWidgets('lists records and taps one', (tester) async {
    MemoryRecord? tapped;
    final records = [
      MemoryRecord(id: 'a', photoPath: '', text: '倒垃圾',
          createdAt: DateTime(2026, 8, 24)),
      MemoryRecord(id: 'b', photoPath: '', text: '吃藥',
          createdAt: DateTime(2026, 8, 23)),
    ];
    await tester.pumpWidget(MaterialApp(
      home: RecordsScreen(records: records, onTap: (r) => tapped = r),
    ));

    expect(find.text('倒垃圾'), findsOneWidget);
    expect(find.text('吃藥'), findsOneWidget);

    await tester.tap(find.text('倒垃圾'));
    expect(tapped?.id, 'a');
  });

  testWidgets('shows empty message when no records', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RecordsScreen(records: const [], onTap: (_) {}),
    ));
    expect(find.text('還沒有記錄'), findsOneWidget);
  });

  testWidgets('pinned 提醒 section appears above plain records', (tester) async {
    final records = [
      MemoryRecord(
        id: 'r1',
        photoPath: '',
        text: '回診',
        createdAt: DateTime(2026, 8, 24),
        isReminder: true,
        reminderAt: DateTime(2026, 8, 25, 10),
      ),
      MemoryRecord(
        id: 'p1',
        photoPath: '',
        text: '天氣',
        createdAt: DateTime(2026, 8, 24),
      ),
    ];
    await tester.pumpWidget(MaterialApp(
      home: RecordsScreen(records: records, onTap: (_) {}),
    ));

    // Section header must exist exactly once.
    expect(find.text('提醒'), findsOneWidget);

    // Reminder tile must appear above the plain record visually.
    final reminderDy = tester.getTopLeft(find.text('回診')).dy;
    final plainDy = tester.getTopLeft(find.text('天氣')).dy;
    expect(reminderDy, lessThan(plainDy));
  });
}
