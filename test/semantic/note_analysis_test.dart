import 'package:flutter_test/flutter_test.dart';
import 'package:reminder/semantic/note_analysis.dart';

void main() {
  test('NoteAnalysis holds fields with sensible defaults', () {
    const a = NoteAnalysis(correctedText: 'hi');
    expect(a.correctedText, 'hi');
    expect(a.isReminder, false);
    expect(a.reminderAt, isNull);
    expect(a.intent, Intent.record);
    expect(a.mentionedContacts, isEmpty);
    expect(a.vaguePart, isNull);
    expect(a.dayBase, isNull);
  });

  test('Intent enum exposes all categories', () {
    expect(Intent.values, [
      Intent.record,
      Intent.reminder,
      Intent.call,
      Intent.visit,
      Intent.medication,
      Intent.shopping,
      Intent.meal,
      Intent.classSession,
      Intent.exercise,
      Intent.investment,
      Intent.date,
      Intent.visitor,
      Intent.social,
      Intent.work,
      Intent.travel,
      Intent.birthday,
      Intent.family,
    ]);
  });
}
