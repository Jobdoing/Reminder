import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminder/screens/photo_view_screen.dart';
import 'package:reminder/services/photo_store.dart';

void main() {
  late Directory documents;

  setUp(() {
    documents = Directory.systemTemp.createTempSync('photo_view_documents');
    PhotoStore.init(documents);
  });

  tearDown(() {
    documents.deleteSync(recursive: true);
  });

  testWidgets('shows an InteractiveViewer for zoom and pan', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PhotoViewScreen(photoPath: 'memory_photos/x.jpg'),
      ),
    );
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    expect(viewer.minScale, 1.0);
    expect(viewer.maxScale, 5.0);
    // pan must be enabled (default true) and not constrained away
    expect(viewer.panEnabled, isTrue);
    expect(viewer.scaleEnabled, isTrue);
  });
}
