import 'package:flutter_test/flutter_test.dart';
import 'package:reminder/semantic/reminder_detector.dart';
import 'package:reminder/semantic/note_analysis.dart';

void main() {
  final now = DateTime(2026, 8, 24, 10, 0); // Mon 2026-08-24 10:00
  const d = ReminderDetector();

  ReminderHit hit(String s) => d.detect(s, now: now);

  group('is reminder', () {
    for (final s in [
      '明天下午三點去看王醫師',
      '後天早上吃藥',
      '明天要回診',
      '記得倒垃圾',
      '等一下要打電話給小明',
      '今天下午拿藥',
      '早上八點量血壓',
      '晚上七點半吃飯',
      '星期三去看醫生',
      '兩小時後吃藥',
      '設定一分鐘後通知我',
      '提醒我繳電費',
    ]) {
      test('"$s" is a reminder', () => expect(hit(s).isReminder, true));
    }
  });

  group('not a reminder', () {
    for (final s in ['今天天氣很好', '這朵花很漂亮', '我孫子很可愛']) {
      test('"$s" is not a reminder', () => expect(hit(s).isReminder, false));
    }
  });

  group('time resolution', () {
    test('明天下午三點 -> next day 15:00', () {
      final at = hit('明天下午三點去看王醫師').at!;
      expect([at.month, at.day, at.hour, at.minute], [8, 25, 15, 0]);
    });
    test('晚上七點半 -> today 19:30', () {
      final at = hit('晚上七點半吃飯').at!;
      expect([at.day, at.hour, at.minute], [24, 19, 30]);
    });
    test('早上八點 -> today 08:00', () {
      final at = hit('早上八點量血壓').at!;
      expect([at.hour, at.minute], [8, 0]);
    });
    test('兩小時後 -> now + 2h', () {
      final at = hit('兩小時後吃藥').at!;
      expect([at.hour, at.minute], [12, 0]);
    });
    test('設定一分鐘後通知我 -> now + 1m', () {
      final at = hit('設定一分鐘後通知我').at!;
      expect(at, DateTime(2026, 8, 24, 10, 1));
    });
    test('星期三 (from Mon) -> Wed', () {
      final at = hit('星期三下午兩點去看醫生').at!;
      expect([at.day, at.hour], [26, 14]);
    });
    test('vague 記得倒垃圾 -> reminder but no time', () {
      final h = hit('記得倒垃圾');
      expect(h.isReminder, true);
      expect(h.at, isNull);
    });
    test('等一下 -> reminder but no time', () {
      expect(hit('等一下要打電話給小明').at, isNull);
    });
  });

  group('date without a time', () {
    final cases = {
      '下禮拜三幫我記得要去看醫生。': DateTime(2026, 9, 2),
      '月底要繳費': DateTime(2026, 8, 31),
      '下周末要聚餐': DateTime(2026, 9, 5),
      '三天後要拿藥': DateTime(2026, 8, 27),
      '後天要回診': DateTime(2026, 8, 26),
      '大後天要回診': DateTime(2026, 8, 27),
    };

    cases.forEach((text, expectedDay) {
      test('"$text" keeps its resolved date', () {
        final h = hit(text);
        expect(h.isReminder, true);
        expect(h.at, isNull);
        expect(h.dayBase, expectedDay);
      });
    });

    test('下禮拜三 with a clock resolves in the following week', () {
      expect(hit('下禮拜三下午兩點看醫生').at, DateTime(2026, 9, 2, 14));
    });
  });

  group('vague part-of-day', () {
    test('明天早上 -> reminder, no clock, morning, tomorrow', () {
      final h = hit('明天早上提醒我要去回診');
      expect(h.isReminder, true);
      expect(h.at, isNull);
      expect(h.vaguePart, DayPart.morning);
      expect([h.dayBase!.month, h.dayBase!.day], [8, 25]);
    });

    test('明天傍晚 -> dusk, tomorrow', () {
      final h = hit('明天傍晚回診');
      expect(h.isReminder, true);
      expect(h.at, isNull);
      expect(h.vaguePart, DayPart.dusk);
      expect([h.dayBase!.month, h.dayBase!.day], [8, 25]);
    });

    test('今天中午 -> noon, today', () {
      final h = hit('今天中午記得吃藥');
      expect(h.isReminder, true);
      expect(h.at, isNull);
      expect(h.vaguePart, DayPart.noon);
      expect([h.dayBase!.month, h.dayBase!.day], [8, 24]);
    });

    test('explicit 明天下午三點 -> concrete, no vaguePart', () {
      final h = hit('明天下午三點去看王醫師');
      expect(h.at, isNotNull);
      expect([h.at!.hour, h.at!.minute], [15, 0]);
      expect(h.vaguePart, isNull);
    });
  });
}
