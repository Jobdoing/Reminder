enum Intent {
  record,
  reminder,
  call,
  visit,
  medication,
  shopping,
  meal,
  classSession,
  exercise,
  investment,
  date,
  visitor,
  social,
  work,
  travel,
  birthday,
  family,
}

/// Vague part-of-day when a reminder has no explicit clock (e.g. 「明天早上」).
enum DayPart { morning, noon, afternoon, dusk, evening }

class NoteAnalysis {
  final String correctedText;
  final bool isReminder;
  final DateTime? reminderAt;
  final Intent intent;
  final List<String> mentionedContacts;

  // [dayBase] is set when a date was resolved without a clock. [vaguePart] is
  // additionally set when the text contains a part-of-day word.
  final DayPart? vaguePart;
  final DateTime? dayBase;

  const NoteAnalysis({
    required this.correctedText,
    this.isReminder = false,
    this.reminderAt,
    this.intent = Intent.record,
    this.mentionedContacts = const [],
    this.vaguePart,
    this.dayBase,
  });
}
