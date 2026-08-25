import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:reminder/models/memory_record.dart';
import 'package:reminder/semantic/note_analysis.dart';
import 'package:reminder/services/part_of_day_store.dart';
import 'package:reminder/services/stt/stt_service.dart';
import 'package:reminder/services/stt/stub_stt_service.dart';
import 'package:reminder/screens/capture_review_screen.dart';

void main() {
  testWidgets('records, shows editable transcript, edits, and saves', (
    tester,
  ) async {
    MemoryRecord? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: CaptureReviewScreen(
          photoPath: '/tmp/x.jpg',
          stt: StubSttService(
            scriptedPartials: ['明天下午看王醫師'],
            finalText: '明天下午看王醫師',
          ),
          onSave: (r) async => saved = r,
          onRetake: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Partial transcript is shown while listening.
    expect(find.text('明天下午看王醫師'), findsOneWidget);

    // Stop listening -> review step.
    await tester.tap(find.text('說完了'));
    await tester.pumpAndSettle();

    // Correct a recognition error in the editable field.
    await tester.enterText(find.byType(TextField), '明天下午看王醫師（記得帶健保卡）');

    await tester.tap(find.text('存起來'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.photoPath, '/tmp/x.jpg');
    expect(saved!.text, '明天下午看王醫師（記得帶健保卡）');
  });

  testWidgets('save cannot be submitted twice while it is still running', (
    tester,
  ) async {
    final saveCompleter = Completer<void>();
    var saveCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: CaptureReviewScreen(
          photoPath: '/tmp/x.jpg',
          stt: StubSttService(finalText: '記住這件事'),
          onSave: (_) {
            saveCount++;
            return saveCompleter.future;
          },
          onRetake: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('說完了'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('存起來'));
    await tester.pump();
    await tester.tap(find.text('存起來'));
    await tester.pump();

    expect(saveCount, 1);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '存起來'))
          .onPressed,
      isNull,
    );

    saveCompleter.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('reminder switch reflects detection and re-analyzes on edit', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CaptureReviewScreen(
          photoPath: '/tmp/x.jpg',
          stt: StubSttService(finalText: '明天下午三點看王醫師'),
          now: DateTime(2026, 8, 24, 10),
          onSave: (_) async {},
          onRetake: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('說完了'));
    await tester.pumpAndSettle();

    // Detected reminder: switch on, resolved time shown with a confirm prompt.
    expect(find.text('這個時間可以嗎？'), findsOneWidget);
    expect(find.text('8/25 15:00'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

    // Editing to a non-reminder re-analyzes: switch follows detection (off),
    // and the time confirm disappears.
    await tester.enterText(find.byType(TextField), '今天天氣很好');
    await tester.pumpAndSettle();
    expect(find.text('這個時間可以嗎？'), findsNothing);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('vague part-of-day shows the default time and asks to confirm', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CaptureReviewScreen(
          photoPath: '/tmp/x.jpg',
          stt: StubSttService(finalText: '明天早上回診'),
          now: DateTime(2026, 8, 24, 10),
          onSave: (_) async {},
          onRetake: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('說完了'));
    await tester.pumpAndSettle();

    // No explicit clock: the morning default (08:00) is filled in and confirmed.
    expect(find.text('這個時間可以嗎？'), findsOneWidget);
    expect(find.text('8/25 08:00'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('date-only reminder defaults to the same time on that day', (
    tester,
  ) async {
    MemoryRecord? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: CaptureReviewScreen(
          photoPath: '/tmp/x.jpg',
          stt: StubSttService(finalText: '明天提醒我'),
          now: DateTime(2026, 8, 24, 10, 37, 42),
          onSave: (record) async => saved = record,
          onRetake: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('說完了'));
    await tester.pumpAndSettle();

    expect(find.text('這個時間可以嗎？'), findsOneWidget);
    expect(find.text('8/25 10:37'), findsOneWidget);
    await tester.tap(find.text('存起來'));
    await tester.pumpAndSettle();
    expect(saved?.reminderAt, DateTime(2026, 8, 25, 10, 37));
  });

  testWidgets('reminder without a date still does not guess a time', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CaptureReviewScreen(
          photoPath: '/tmp/x.jpg',
          stt: StubSttService(finalText: '提醒我吃藥'),
          now: DateTime(2026, 8, 24, 10, 37),
          onSave: (_) async {},
          onRetake: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('說完了'));
    await tester.pumpAndSettle();

    expect(find.text('這個時間可以嗎？'), findsNothing);
    expect(find.text('沒有抓到時間，時間到不會響'), findsOneWidget);
  });

  testWidgets('a past vague time is not moved to the next day', (tester) async {
    MemoryRecord? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: CaptureReviewScreen(
          photoPath: '/tmp/x.jpg',
          stt: StubSttService(finalText: '早上提醒我吃藥'),
          now: DateTime(2026, 8, 24, 9),
          onSave: (record) async => saved = record,
          onRetake: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('說完了'));
    await tester.pumpAndSettle();

    expect(find.text('8/24 08:00'), findsOneWidget);
    await tester.tap(find.text('存起來'));
    await tester.pumpAndSettle();

    expect(saved, isNull);
    expect(find.text('提醒時間已經過了，請重新說明日期或關閉提醒'), findsOneWidget);
  });

  testWidgets('changing a vague time learns it for the next reminder', (
    tester,
  ) async {
    MemoryRecord? saved;
    await tester.runAsync(() async {
      Hive.init(null);
      await Hive.openBox('part_of_day', bytes: Uint8List(0));
      await PartOfDayStore.init();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: CaptureReviewScreen(
          photoPath: '/tmp/x.jpg',
          stt: StubSttService(finalText: '明天早上回診'),
          now: DateTime(2026, 8, 24, 10),
          onSave: (record) async => saved = record,
          onRetake: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('說完了'));
    await tester.pumpAndSettle();

    expect(find.text('8/25 08:00'), findsOneWidget);
    await tester.tap(find.text('8/25 08:00'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    final picker = tester.widget<CupertinoDatePicker>(
      find.byType(CupertinoDatePicker),
    );
    picker.onDateTimeChanged(DateTime(2026, 8, 25, 9));
    await tester.tap(find.text('確定'));
    await tester.pumpAndSettle();

    expect(PartOfDayStore.timeFor(DayPart.morning), (9, 0));
    expect(find.text('8/25 09:00'), findsOneWidget);

    await tester.tap(find.text('存起來'));
    await tester.pumpAndSettle();
    expect(saved?.reminderAt, DateTime(2026, 8, 25, 9));

    await tester.pumpWidget(
      MaterialApp(
        home: CaptureReviewScreen(
          key: UniqueKey(),
          photoPath: '/tmp/x.jpg',
          stt: StubSttService(finalText: '後天早上吃藥'),
          now: DateTime(2026, 8, 24, 10),
          onSave: (_) async {},
          onRetake: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('說完了'));
    await tester.pumpAndSettle();
    expect(find.text('8/26 09:00'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(Hive.close);
  });

  testWidgets('time picker stays usable with large text', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final textScale = ValueNotifier(1.0);
    addTearDown(textScale.dispose);

    await tester.pumpWidget(
      ValueListenableBuilder<double>(
        valueListenable: textScale,
        builder: (context, scale, child) => MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: CaptureReviewScreen(
            photoPath: '/tmp/x.jpg',
            stt: StubSttService(finalText: '明天早上回診'),
            now: DateTime(2026, 8, 24, 10),
            onSave: (_) async {},
            onRetake: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('說完了'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('8/25 08:00'));
    await tester.pumpAndSettle();
    textScale.value = 1.6;
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    expect(find.text('選擇時間'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('確定'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('turning the reminder switch off saves a non-reminder', (
    tester,
  ) async {
    MemoryRecord? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: CaptureReviewScreen(
          photoPath: '/tmp/x.jpg',
          stt: StubSttService(finalText: '明天下午三點看王醫師'),
          now: DateTime(2026, 8, 24, 10),
          onSave: (r) async => saved = r,
          onRetake: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('說完了'));
    await tester.pumpAndSettle();

    // Detected as a reminder; user turns it off.
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    await tester.tap(find.text('存起來'));
    await tester.pumpAndSettle();
    expect(saved!.isReminder, isFalse);
    expect(saved!.reminderAt, isNull);
  });

  testWidgets('retake calls onRetake', (tester) async {
    var retook = false;
    await tester.pumpWidget(
      MaterialApp(
        home: CaptureReviewScreen(
          photoPath: '/tmp/x.jpg',
          stt: StubSttService(finalText: 'hi'),
          onSave: (_) async {},
          onRetake: () => retook = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('說完了'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重講'));
    await tester.pumpAndSettle();
    expect(retook, isTrue);
  });

  testWidgets('leaving the listening screen stops speech recognition', (
    tester,
  ) async {
    final stt = _TrackingSttService();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CaptureReviewScreen(
                  photoPath: '/tmp/x.jpg',
                  stt: stt,
                  onSave: (_) async {},
                  onRetake: () {},
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('正在聽… 請說話'), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();

    expect(stt.stopCount, 1);
  });

  testWidgets('a late speech start is stopped after the screen is disposed', (
    tester,
  ) async {
    final startCompleter = Completer<Stream<String>>();
    final stt = _TrackingSttService(startCompleter: startCompleter);
    await tester.pumpWidget(
      MaterialApp(
        home: CaptureReviewScreen(
          photoPath: '/tmp/x.jpg',
          stt: stt,
          onSave: (_) async {},
          onRetake: () {},
        ),
      ),
    );
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    startCompleter.complete(const Stream<String>.empty());
    await tester.pumpAndSettle();

    expect(stt.stopCount, 2);
  });

  testWidgets('speech start failure falls back to editable text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CaptureReviewScreen(
          photoPath: '/tmp/x.jpg',
          stt: _FailingSttService(),
          onSave: (_) async {},
          onRetake: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('無法使用麥克風，請直接打字'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('正在聽… 請說話'), findsNothing);
  });

  testWidgets('missing offline model shows the correct guidance', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CaptureReviewScreen(
          photoPath: '/tmp/x.jpg',
          stt: _FailingSttService(
            PlatformException(code: 'MODEL_DOWNLOAD_FAILED'),
          ),
          onSave: (_) async {},
          onRetake: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('尚未安裝離線中文語音，請連上網路後再試'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}

class _FailingSttService implements SttService {
  _FailingSttService([this.error = const FormatException('Unavailable')]);

  final Object error;

  @override
  bool get isReady => false;

  @override
  Future<void> init() async {}

  @override
  Future<Stream<String>> start() async => throw error;

  @override
  Future<String> stop() async => '';
}

class _TrackingSttService implements SttService {
  _TrackingSttService({this.startCompleter});

  final Completer<Stream<String>>? startCompleter;
  int stopCount = 0;

  @override
  bool get isReady => true;

  @override
  Future<void> init() async {}

  @override
  Future<Stream<String>> start() async =>
      startCompleter?.future ?? const Stream<String>.empty();

  @override
  Future<String> stop() async {
    stopCount++;
    return '';
  }
}
