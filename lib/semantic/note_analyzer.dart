import 'intent_classifier.dart';
import 'name_corrector.dart';
import 'note_analysis.dart';
import 'reminder_detector.dart';

class NoteAnalyzer {
  final ReminderDetector _reminder;

  const NoteAnalyzer({ReminderDetector reminder = const ReminderDetector()})
      : _reminder = reminder;

  NoteAnalysis analyze(
    String text, {
    DateTime? now,
    List<String> contacts = const [],
  }) {
    // Run NameCorrector first so downstream detector/classifier see clean text.
    final correction = const NameCorrector().correct(text, contacts);
    final corrected = correction.text;

    final hit = _reminder.detect(corrected, now: now);
    return NoteAnalysis(
      correctedText: corrected,
      isReminder: hit.isReminder,
      reminderAt: hit.at,
      intent: const IntentClassifier().classify(corrected),
      mentionedContacts: correction.mentioned,
      vaguePart: hit.vaguePart,
      dayBase: hit.dayBase,
    );
  }
}
