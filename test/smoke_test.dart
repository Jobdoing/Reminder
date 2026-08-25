import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminder/main.dart';

void main() {
  testWidgets('app builds with title 銀髮記憶', (tester) async {
    await tester.pumpWidget(const ReminderApp());
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, '銀髮記憶');
  });
}
