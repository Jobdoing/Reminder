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
  test('exact name is detected, unchanged', () {
    final r = nc.correct('打電話給陳美玲', contacts);
    expect(r.text, '打電話給陳美玲');
    expect(r.mentioned, contains('陳美玲'));
  });
  test('does not over-correct an unrelated word', () {
    final r = nc.correct('今天天氣很好', contacts);
    expect(r.text, '今天天氣很好');
    expect(r.mentioned, isEmpty);
  });
}
