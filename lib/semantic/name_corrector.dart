// Pure Dart — no Flutter imports.

import 'dart:math';

import 'package:pinyin/pinyin.dart';

class NameCorrection {
  final String text;
  final List<String> mentioned;

  const NameCorrection(this.text, this.mentioned);
}

class NameCorrector {
  const NameCorrector();

  static const _minimumScore = 0.78;
  static const _contextualMinimumScore = 0.66;
  static const _ambiguityMargin = 0.12;
  static const _relationshipCues = {'跟', '和', '與', '找', '給', '約', '問', '叫'};

  NameCorrection correct(String text, List<String> contacts) {
    final textChars = _toCharList(text);
    if (textChars.isEmpty || contacts.isEmpty) {
      return NameCorrection(text, const []);
    }

    final textReadings = textChars.map(_readings).toList();
    final candidates = <_Candidate>[];
    final names = contacts
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toSet();

    for (final name in names) {
      final nameChars = _toCharList(name);
      final exactSpans = _exactSpans(textChars, nameChars);
      if (exactSpans.isNotEmpty) {
        candidates.addAll(
          exactSpans.map(
            (span) => _Candidate(name, span.start, span.end, 1, true),
          ),
        );
        continue;
      }

      // NOTE(ceiling): A one-syllable approximate match is unsafe without a
      // contextual model; exact one-character contact names still work.
      if (nameChars.length < 2) continue;

      final match = _bestSpan(
        textChars,
        textReadings,
        nameChars,
        nameChars.map(_readings).toList(),
      );
      // NOTE(ceiling): A relationship cue permits one severe STT syllable
      // error; use a trained name-span model if real speech needs more context.
      final hasStrongContext =
          _hasRelationshipCue(textChars, match.start) &&
          _hasTwoExactReadings(textReadings, match.start, match.end, nameChars);
      final minimumScore = hasStrongContext
          ? _contextualMinimumScore
          : _minimumScore;
      if (match.score >= minimumScore) {
        candidates.add(
          _Candidate(name, match.start, match.end, match.score, false),
        );
      }
    }

    final accepted = _acceptUnambiguous(candidates);
    final replacements =
        accepted.where((candidate) => !candidate.exact).toList()
          ..sort((a, b) => b.start.compareTo(a.start));
    final corrected = List<String>.of(textChars);
    for (final replacement in replacements) {
      corrected.replaceRange(
        replacement.start,
        replacement.end,
        _toCharList(replacement.name),
      );
    }

    accepted.sort((a, b) => a.start.compareTo(b.start));
    final mentioned = <String>[];
    for (final candidate in accepted) {
      if (!mentioned.contains(candidate.name)) mentioned.add(candidate.name);
    }
    return NameCorrection(corrected.join(), mentioned);
  }

  static List<_Candidate> _acceptUnambiguous(List<_Candidate> candidates) {
    final ranked = List<_Candidate>.of(candidates)
      ..sort((a, b) {
        if (a.exact != b.exact) return a.exact ? -1 : 1;
        return b.score.compareTo(a.score);
      });
    final accepted = <_Candidate>[];

    for (final candidate in ranked) {
      if (accepted.any((selected) => _overlaps(candidate, selected))) continue;
      if (!candidate.exact) {
        final competingScores = candidates
            .where(
              (other) =>
                  other.name != candidate.name && _overlaps(candidate, other),
            )
            .map((other) => other.score);
        final bestCompetitor = competingScores.isEmpty
            ? null
            : competingScores.reduce(max);
        if (bestCompetitor != null &&
            candidate.score - bestCompetitor < _ambiguityMargin) {
          continue;
        }
      }
      accepted.add(candidate);
    }
    return accepted;
  }

  static bool _overlaps(_Candidate a, _Candidate b) =>
      a.start < b.end && b.start < a.end;

  static bool _hasRelationshipCue(List<String> text, int nameStart) =>
      nameStart > 0 && _relationshipCues.contains(text[nameStart - 1]);

  static bool _hasTwoExactReadings(
    List<List<String>> textReadings,
    int start,
    int end,
    List<String> nameChars,
  ) {
    if (end - start != nameChars.length) return false;
    var exact = 0;
    for (var index = 0; index < nameChars.length; index++) {
      final nameReadings = _readings(nameChars[index]);
      if (textReadings[start + index].any(nameReadings.contains)) exact++;
    }
    return exact >= 2;
  }

  static List<_Span> _exactSpans(List<String> text, List<String> name) {
    final spans = <_Span>[];
    if (name.length > text.length) return spans;
    for (var start = 0; start <= text.length - name.length; start++) {
      var equal = true;
      for (var offset = 0; offset < name.length; offset++) {
        if (text[start + offset] != name[offset]) {
          equal = false;
          break;
        }
      }
      if (equal) spans.add(_Span(start, start + name.length));
    }
    return spans;
  }

  static _SpanMatch _bestSpan(
    List<String> textChars,
    List<List<String>> textReadings,
    List<String> nameChars,
    List<List<String>> nameReadings,
  ) {
    final rows = nameChars.length + 1;
    final columns = textChars.length + 1;
    final costs = List.generate(rows, (_) => List.filled(columns, 0.0));
    final starts = List.generate(rows, (_) => List.filled(columns, 0));

    for (var column = 0; column < columns; column++) {
      starts[0][column] = column;
    }
    for (var row = 1; row < rows; row++) {
      costs[row][0] = row.toDouble();
    }

    for (var row = 1; row < rows; row++) {
      for (var column = 1; column < columns; column++) {
        var bestCost =
            costs[row - 1][column - 1] +
            _substitutionCost(
              textChars[column - 1],
              textReadings[column - 1],
              nameChars[row - 1],
              nameReadings[row - 1],
            );
        var bestStart = starts[row - 1][column - 1];

        final missingFromTranscript = costs[row - 1][column] + 1;
        if (missingFromTranscript < bestCost) {
          bestCost = missingFromTranscript;
          bestStart = starts[row - 1][column];
        }

        final extraInTranscript = costs[row][column - 1] + 1;
        if (extraInTranscript < bestCost) {
          bestCost = extraInTranscript;
          bestStart = starts[row][column - 1];
        }

        costs[row][column] = bestCost;
        starts[row][column] = bestStart;
      }
    }

    var bestEnd = 1;
    var bestCost = costs[nameChars.length][bestEnd];
    for (var end = 2; end < columns; end++) {
      final candidateCost = costs[nameChars.length][end];
      final candidateLength = end - starts[nameChars.length][end];
      final bestLength = bestEnd - starts[nameChars.length][bestEnd];
      if (candidateCost < bestCost ||
          (candidateCost == bestCost &&
              (candidateLength - nameChars.length).abs() <
                  (bestLength - nameChars.length).abs())) {
        bestCost = candidateCost;
        bestEnd = end;
      }
    }
    final start = starts[nameChars.length][bestEnd];
    final score = max(0.0, 1 - bestCost / nameChars.length);
    return _SpanMatch(start, bestEnd, score);
  }

  static double _substitutionCost(
    String textChar,
    List<String> textReadings,
    String nameChar,
    List<String> nameReadings,
  ) {
    if (textChar == nameChar) return 0;
    var best = 1.0;
    for (final textReading in textReadings) {
      for (final nameReading in nameReadings) {
        final longest = max(textReading.length, nameReading.length);
        if (longest == 0) continue;
        best = min(best, _levenshtein(textReading, nameReading) / longest);
      }
    }
    return best;
  }

  static List<String> _readings(String character) {
    final readings = PinyinHelper.convertToPinyinArray(
      character,
      PinyinFormat.WITHOUT_TONE,
    );
    return readings.isEmpty ? [character.toLowerCase()] : readings;
  }

  static List<String> _toCharList(String value) =>
      value.runes.map(String.fromCharCode).toList();

  static int _levenshtein(String a, String b) {
    final previous = List<int>.generate(b.length + 1, (index) => index);
    for (var row = 1; row <= a.length; row++) {
      var diagonal = previous[0];
      previous[0] = row;
      for (var column = 1; column <= b.length; column++) {
        final above = previous[column];
        previous[column] = min(
          min(previous[column] + 1, previous[column - 1] + 1),
          diagonal + (a[row - 1] == b[column - 1] ? 0 : 1),
        );
        diagonal = above;
      }
    }
    return previous[b.length];
  }
}

class _Candidate {
  const _Candidate(this.name, this.start, this.end, this.score, this.exact);

  final String name;
  final int start;
  final int end;
  final double score;
  final bool exact;
}

class _Span {
  const _Span(this.start, this.end);

  final int start;
  final int end;
}

class _SpanMatch extends _Span {
  const _SpanMatch(super.start, super.end, this.score);

  final double score;
}
