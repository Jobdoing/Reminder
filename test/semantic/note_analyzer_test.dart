import 'package:flutter_test/flutter_test.dart';
import 'package:reminder/semantic/note_analyzer.dart';
import 'package:reminder/semantic/note_analysis.dart';

void main() {
  const analyzer = NoteAnalyzer();

  test('analyze fills reminder + time', () {
    final a = analyzer.analyze('明天下午三點去看王醫師', now: DateTime(2026, 8, 24, 10));
    expect(a.isReminder, true);
    expect(a.reminderAt!.hour, 15);
    expect(a.correctedText, '明天下午三點去看王醫師');
  });

  test('vague part-of-day flows through to analysis', () {
    final a = analyzer.analyze('明天早上回診', now: DateTime(2026, 8, 24, 10));
    expect(a.isReminder, true);
    expect(a.reminderAt, isNull);
    expect(a.vaguePart, DayPart.morning);
    expect([a.dayBase!.month, a.dayBase!.day], [8, 25]);
  });

  test('non-reminder note', () {
    final a = analyzer.analyze('今天天氣很好', now: DateTime(2026, 8, 24, 10));
    expect(a.isReminder, false);
    expect(a.reminderAt, isNull);
  });

  test('intent classified by IntentClassifier', () {
    final a = analyzer.analyze('打電話給小明', now: DateTime(2026, 8, 24, 10));
    expect(a.intent, Intent.call);
  });

  test('name correction via contacts param', () {
    final a = analyzer.analyze(
      '打電話給王小名',
      now: DateTime(2026, 8, 24, 10),
      contacts: ['王小明'],
    );
    expect(a.correctedText, '打電話給王小明');
    expect(a.mentionedContacts, contains('王小明'));
  });
}
