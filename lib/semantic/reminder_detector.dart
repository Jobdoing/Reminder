// NOTE(ceiling): Heuristic keyword-match detector. Not full NLP.
// Ceiling: compound/ambiguous phrases (e.g. 今天天氣很好 vs 今天下午拿藥 must be
// disambiguated by checking for an accompanying clock word). Future upgrade path:
// replace keyword sets with a small intent model or dependency-parsed slot-filler.

import 'note_analysis.dart';

class ReminderHit {
  final bool isReminder;
  final DateTime? at;
  // [dayBase] is the resolved calendar day when the text contains a date but no
  // clock. [vaguePart] is additionally set when a part-of-day word is present.
  final DayPart? vaguePart;
  final DateTime? dayBase;
  const ReminderHit(this.isReminder, this.at, {this.vaguePart, this.dayBase});
}

class ReminderDetector {
  const ReminderDetector();

  // Reminder-trigger words (always make the note a reminder).
  static const _reminderWords = ['記得', '提醒', '別忘', '忘記'];

  // Vague-soon words (reminder but no concrete time → at = null).
  static const _vagueSoonWords = ['等一下', '等等', '待會', '晚點'];

  // Strong future-day words (alone make it a reminder without a clock).
  // 今天 is NOT included — it only contributes to time resolution when a clock
  // word is also present.
  static const _strongFutureDayWords = ['明天', '後天', '大後天'];

  // Clock-period prefixes.
  static const _amPrefixes = ['早上', '上午'];
  static const _pmPrefixes = ['下午', '晚上'];
  static const _noonPrefix = '中午';
  static const _duskPrefix = '傍晚';

  // Part-of-day words → DayPart (checked in insertion order; specific first).
  static const _dayPartWords = <String, DayPart>{
    '早上': DayPart.morning,
    '上午': DayPart.morning,
    '中午': DayPart.noon,
    '下午': DayPart.afternoon,
    '傍晚': DayPart.dusk,
    '晚上': DayPart.evening,
  };

  static DayPart? _detectDayPart(String text) {
    for (final e in _dayPartWords.entries) {
      if (text.contains(e.key)) return e.value;
    }
    return null;
  }

  // Chinese digit characters (一..九, 兩) mapping to int 1..9, 2.
  static int? _parseChineseDigit(String ch) {
    const map = {
      '一': 1,
      '二': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '七': 7,
      '八': 8,
      '九': 9,
      '兩': 2,
      '十': 10,
    };
    return map[ch];
  }

  // Parse a Chinese or Arabic number from the start of [s].
  // Returns null if no number found.
  // Handles: single Chinese digit, 十 alone (=10), 十N (=10+N), NaN, Arabic digits.
  static int? _parseLeadingNumber(String s) {
    if (s.isEmpty) return null;

    // Arabic digit(s)
    final arabicMatch = RegExp(r'^\d+').firstMatch(s);
    if (arabicMatch != null) return int.parse(arabicMatch.group(0)!);

    // 十 alone or 十N
    if (s.startsWith('十')) {
      if (s.length >= 2) {
        final next = _parseChineseDigit(s[1]);
        if (next != null) return 10 + next;
      }
      return 10;
    }

    // Single Chinese digit possibly followed by 十 (e.g. 三十)
    final d = _parseChineseDigit(s[0]);
    if (d == null) return null;
    if (s.length >= 2 && s[1] == '十') {
      if (s.length >= 3) {
        final next = _parseChineseDigit(s[2]);
        if (next != null) return d * 10 + next;
      }
      return d * 10;
    }
    return d;
  }

  // Resolve N小時後 → DateTime (now + N hours). Returns null if not found.
  static DateTime? _resolveRelativeHours(String text, DateTime now) {
    // Pattern: <number>小時後
    final re = RegExp(r'([一二三四五六七八九十兩\d]+)小時後');
    final m = re.firstMatch(text);
    if (m == null) return null;
    final n = _parseLeadingNumber(m.group(1)!);
    if (n == null) return null;
    return now.add(Duration(hours: n));
  }

  // Resolve N分鐘後 → DateTime (now + N minutes). Returns null if not found.
  static DateTime? _resolveRelativeMinutes(String text, DateTime now) {
    final re = RegExp(r'([一二三四五六七八九十兩\d]+)分鐘後');
    final m = re.firstMatch(text);
    if (m == null) return null;
    final n = _parseLeadingNumber(m.group(1)!);
    if (n == null) return null;
    return now.add(Duration(minutes: n));
  }

  // Resolve N天後 → date offset. Returns null if not found.
  static DateTime? _resolveRelativeDays(String text, DateTime now) {
    final re = RegExp(r'([一二三四五六七八九十兩\d]+)天後');
    final m = re.firstMatch(text);
    if (m == null) return null;
    final n = _parseLeadingNumber(m.group(1)!);
    if (n == null) return null;
    return DateTime(now.year, now.month, now.day + n);
  }

  // Resolve 星期X / 禮拜X / 週X / 周X. A leading 下 means the
  // weekday in the following calendar week, not merely the next occurrence.
  // Returns null if not found.
  static DateTime? _resolveWeekday(String text, DateTime now) {
    final re = RegExp(r'(下)?(?:星期|禮拜|週|周)([一二三四五六日天])');
    final m = re.firstMatch(text);
    if (m == null) return null;

    const dayMap = {
      '一': 1,
      '二': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '日': 7,
      '天': 7,
    };
    final targetWeekday = dayMap[m.group(2)!];
    if (targetWeekday == null) return null;

    final today = now.weekday; // Mon=1..Sun=7
    if (m.group(1) != null) {
      final daysAhead = 7 - today + targetWeekday;
      return DateTime(now.year, now.month, now.day + daysAhead);
    }

    // Find next occurrence strictly after today.
    int daysAhead = targetWeekday - today;
    if (daysAhead <= 0) daysAhead += 7;
    return DateTime(now.year, now.month, now.day + daysAhead);
  }

  // Resolve 下週末 / 下周末 to Saturday of the following calendar week.
  static DateTime? _resolveNextWeekend(String text, DateTime now) {
    if (!RegExp(r'下(?:週|周)末').hasMatch(text)) return null;
    final daysAhead = 13 - now.weekday;
    return DateTime(now.year, now.month, now.day + daysAhead);
  }

  // Resolve 月底 to the final calendar day of the current month.
  static DateTime? _resolveMonthEnd(String text, DateTime now) {
    if (!text.contains('月底')) return null;
    return DateTime(now.year, now.month + 1, 0);
  }

  // Resolve an absolute day offset from day-offset words.
  // Returns null if no strong future day word found and 今天 is not present
  // (today base is always the fallback when a clock is present).
  // Returns the base date (time is resolved separately).
  static DateTime _resolveDay(String text, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);

    if (text.contains('大後天')) {
      return today.add(const Duration(days: 3));
    }
    if (text.contains('後天')) {
      return today.add(const Duration(days: 2));
    }
    if (text.contains('明天')) {
      return today.add(const Duration(days: 1));
    }
    return today;
  }

  // Parse clock time from text. Returns null if no clock found.
  // Handles: 早上/上午→AM, 下午/晚上→PM, 中午→12, then X點(Y分)?, 半→30min.
  static _ClockResolution? _resolveClock(String text) {
    // 中午 with optional X點
    if (text.contains(_noonPrefix)) {
      // Check for 中午X點
      final re = RegExp(r'中午([一二三四五六七八九十兩\d]+)點(?:([一二三四五六七八九十兩\d]+)分)?');
      final m = re.firstMatch(text);
      if (m != null) {
        final h = _parseLeadingNumber(m.group(1)!) ?? 12;
        final min = m.group(2) != null
            ? (_parseLeadingNumber(m.group(2)!) ?? 0)
            : 0;
        return _ClockResolution(hour: h, minute: min);
      }
    }

    // AM: 早上/上午
    for (final prefix in _amPrefixes) {
      if (text.contains(prefix)) {
        final result = _extractHourMinute(text, prefix, pm: false);
        if (result != null) return result;
      }
    }

    // PM: 下午/晚上
    for (final prefix in _pmPrefixes) {
      if (text.contains(prefix)) {
        final result = _extractHourMinute(text, prefix, pm: true);
        if (result != null) return result;
      }
    }

    // Bare X點 (no period prefix) — treat as clock trigger without AM/PM
    // e.g. "八點" alone. Return hour as-is (no PM shift).
    final bareRe = RegExp(r'([一二三四五六七八九十兩\d]+)點(?:([一二三四五六七八九十兩\d]+)分|半)?');
    final bm = bareRe.firstMatch(text);
    if (bm != null) {
      final h = _parseLeadingNumber(bm.group(1)!) ?? 0;
      int min = 0;
      if (bm.group(2) != null) {
        min = _parseLeadingNumber(bm.group(2)!) ?? 0;
      } else if (bm.group(0)!.endsWith('半')) {
        min = 30;
      }
      return _ClockResolution(hour: h, minute: min);
    }

    return null;
  }

  static _ClockResolution? _extractHourMinute(
    String text,
    String prefix, {
    required bool pm,
  }) {
    // Try: <prefix><number>點(<number>分|半)?
    final re = RegExp(
      prefix + r'([一二三四五六七八九十兩\d]+)點(?:([一二三四五六七八九十兩\d]+)分|(半))?',
    );
    final m = re.firstMatch(text);
    if (m != null) {
      int h = _parseLeadingNumber(m.group(1)!) ?? 0;
      if (pm && h < 12) h += 12;
      int min = 0;
      if (m.group(2) != null) {
        min = _parseLeadingNumber(m.group(2)!) ?? 0;
      } else if (m.group(3) != null) {
        // 半 → 30
        min = 30;
      }
      return _ClockResolution(hour: h, minute: min);
    }

    // Also handle: <prefix> alone triggers a clock period (reminder), even without 點.
    // But we only return a time if we have an actual hour. Without 點 there's no concrete time.
    // Return null — the prefix alone is enough to make it a reminder (handled separately),
    // but we can't pin an exact time.
    return null;
  }

  // Check if text contains any clock-trigger word (period prefix or X點).
  static bool _hasClockWord(String text) {
    for (final p in [
      ..._amPrefixes,
      ..._pmPrefixes,
      _noonPrefix,
      _duskPrefix,
    ]) {
      if (text.contains(p)) return true;
    }
    // X點 pattern
    return RegExp(r'[一二三四五六七八九十兩\d]+點').hasMatch(text);
  }

  // Check if text contains a strong date trigger.
  static bool _hasStrongFuture(String text) {
    for (final w in _strongFutureDayWords) {
      if (text.contains(w)) return true;
    }
    if (RegExp(r'(?:下)?(?:星期|禮拜|週|周)[一二三四五六日天]').hasMatch(text)) {
      return true;
    }
    if (RegExp(r'下(?:週|周)末').hasMatch(text)) return true;
    if (text.contains('月底')) return true;
    if (RegExp(r'[一二三四五六七八九十兩\d]+天後').hasMatch(text)) return true;
    if (RegExp(r'[一二三四五六七八九十兩\d]+小時後').hasMatch(text)) return true;
    if (RegExp(r'[一二三四五六七八九十兩\d]+分鐘後').hasMatch(text)) return true;
    return false;
  }

  ReminderHit detect(String text, {DateTime? now}) {
    final base = now ?? DateTime.now();

    // Check reminder-word triggers.
    final hasReminderWord = _reminderWords.any(text.contains);

    // Check vague-soon triggers.
    final hasVagueSoon = _vagueSoonWords.any(text.contains);

    // Check strong future-day triggers.
    final hasStrongFuture = _hasStrongFuture(text);

    // Check clock triggers.
    final hasClockWord = _hasClockWord(text);

    // 今天 is only a reminder trigger when accompanied by a clock word.
    final hasToday = text.contains('今天');
    final todayTrigger = hasToday && hasClockWord;

    final isReminder =
        hasReminderWord ||
        hasVagueSoon ||
        hasStrongFuture ||
        hasClockWord ||
        todayTrigger;

    if (!isReminder) return const ReminderHit(false, null);

    // --- Time resolution ---

    // Vague-soon or reminder-word-only → no concrete time.
    if ((hasVagueSoon || hasReminderWord) &&
        !hasStrongFuture &&
        !hasClockWord) {
      return const ReminderHit(true, null);
    }

    // N分鐘後 → full timestamp.
    final relMinutes = _resolveRelativeMinutes(text, base);
    if (relMinutes != null) {
      return ReminderHit(true, relMinutes);
    }

    // N小時後 → full timestamp.
    final relHours = _resolveRelativeHours(text, base);
    if (relHours != null) {
      return ReminderHit(true, relHours);
    }

    // Resolve the day base (defaults to today when no day word is present).
    DateTime dayBase = DateTime(base.year, base.month, base.day);

    // Check N天後 first.
    final relDays = _resolveRelativeDays(text, base);
    if (relDays != null) {
      dayBase = relDays;
    } else {
      final nextWeekend = _resolveNextWeekend(text, base);
      if (nextWeekend != null) {
        dayBase = nextWeekend;
      } else {
        // Check weekday.
        final weekday = _resolveWeekday(text, base);
        if (weekday != null) {
          dayBase = weekday;
        } else {
          final monthEnd = _resolveMonthEnd(text, base);
          if (monthEnd != null) {
            dayBase = monthEnd;
          } else {
            // Check offset words.
            dayBase = _resolveDay(text, base);
          }
        }
      }
    }

    // An explicit clock requires an actual X點 in the text. Only then do we pin a
    // concrete time; a bare part-of-day (incl. 中午) stays vague so it goes through
    // the "show the time and ask" + per-part learning flow.
    final hasExplicitClock = RegExp(r'[一二三四五六七八九十兩\d]+點').hasMatch(text);
    if (hasExplicitClock) {
      final clock = _resolveClock(text);
      if (clock != null) {
        return ReminderHit(
          true,
          DateTime(
            dayBase.year,
            dayBase.month,
            dayBase.day,
            clock.hour,
            clock.minute,
          ),
        );
      }
    }

    // No explicit clock. If a part-of-day word is present, expose the part-of-day
    // + resolved day so the UI can fill a default/learned time and ask the user.
    final part = _detectDayPart(text);
    if (part != null) {
      return ReminderHit(true, null, vaguePart: part, dayBase: dayBase);
    }

    // Preserve a recognised date even when the user did not say a time. The UI
    // combines it with the current hour/minute and asks the user to confirm.
    if (hasStrongFuture) {
      return ReminderHit(true, null, dayBase: dayBase);
    }

    // Reminder with no date or time at all (e.g. 記得倒垃圾).
    return const ReminderHit(true, null);
  }
}

class _ClockResolution {
  final int hour;
  final int minute;
  const _ClockResolution({required this.hour, required this.minute});
}
