import 'package:flutter_test/flutter_test.dart';
import 'package:reminder/semantic/name_corrector.dart';

void main() {
  const nc = NameCorrector();
  const contacts = ['王小明', '陳美玲', '張阿嬤', '王醫師'];

  test('corrects a one-off typo name', () {
    final r = nc.correct('明天下午去看王小名', contacts);
    expect(r.text, '明天下午去看王小明');
    expect(r.mentioned, contains('王小明'));
  });

  test('corrects similar final sounds without requiring an exact surname', () {
    final r = nc.correct('我明天下午要跟李佩明約是下午茶', ['李沛米']);
    expect(r.text, '我明天下午要跟李沛米約是下午茶');
    expect(r.mentioned, ['李沛米']);
  });

  test('corrects the real STT output when relationship context is present', () {
    final r = nc.correct('提醒我明天下午要跟李佩瑜吃飯', ['李沛米']);
    expect(r.text, '提醒我明天下午要跟李沛米吃飯');
    expect(r.mentioned, ['李沛米']);
  });

  test('uses an exact PERSON span to correct a name at sentence start', () {
    final r = nc.correct(
      '李佩瑜明天下午來吃飯',
      ['李沛米'],
      personSpans: const [PersonSpan(0, 3)],
    );
    expect(r.text, '李沛米明天下午來吃飯');
    expect(r.mentioned, ['李沛米']);
  });

  test('uses an exact PERSON span after an arbitrary prefix', () {
    final r = nc.correct(
      '明天下午記得陪李佩瑜吃飯',
      ['李沛米'],
      personSpans: const [PersonSpan(7, 10)],
    );
    expect(r.text, '明天下午記得陪李沛米吃飯');
    expect(r.mentioned, ['李沛米']);
  });

  test('corrects a two-character homophone', () {
    final r = nc.correct('明天找吳名', ['吳明']);
    expect(r.text, '明天找吳明');
    expect(r.mentioned, ['吳明']);
  });

  test('corrects a four-character name without a name-length rule', () {
    final r = nc.correct('明天跟歐陽智民吃飯', ['歐陽志明']);
    expect(r.text, '明天跟歐陽志明吃飯');
    expect(r.mentioned, ['歐陽志明']);
  });

  test('corrects a near-sounding surname', () {
    final r = nc.correct('明天找倪志明', ['黎志明']);
    expect(r.text, '明天找黎志明');
    expect(r.mentioned, ['黎志明']);
  });

  test('corrects common near-sound initials and finals', () {
    const cases = {'明天找曾中明': '曾宗明', '明天找劉來文': '劉乃文', '明天找陳文森': '陳文生'};
    for (final entry in cases.entries) {
      final r = nc.correct(entry.key, [entry.value]);
      expect(r.text, '明天找${entry.value}');
      expect(r.mentioned, [entry.value]);
    }
  });

  test('exact name is detected, unchanged', () {
    final r = nc.correct('打電話給陳美玲', contacts);
    expect(r.text, '打電話給陳美玲');
    expect(r.mentioned, contains('陳美玲'));
  });

  test('does not choose between equally plausible homophones', () {
    final r = nc.correct('明天找王小名', ['王小明', '王曉鳴']);
    expect(r.text, '明天找王小名');
    expect(r.mentioned, isEmpty);
  });

  test('does not over-correct an unrelated word', () {
    final r = nc.correct('今天天氣很好', contacts);
    expect(r.text, '今天天氣很好');
    expect(r.mentioned, isEmpty);
  });

  test('does not mistake an ordinary phrase for a contact', () {
    final r = nc.correct('今天買李子很好吃', ['李沛米']);
    expect(r.text, '今天買李子很好吃');
    expect(r.mentioned, isEmpty);
  });

  test('relationship context alone does not force a weak match', () {
    final r = nc.correct('今天跟李子買水果', ['李沛米']);
    expect(r.text, '今天跟李子買水果');
    expect(r.mentioned, isEmpty);
  });

  test('a shorter false PERSON span cannot relax another candidate', () {
    final r = nc.correct(
      '今天跟李子買水果',
      ['李沛米'],
      personSpans: const [PersonSpan(3, 5)],
    );
    expect(r.text, '今天跟李子買水果');
    expect(r.mentioned, isEmpty);
  });
}
