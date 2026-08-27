import 'package:flutter_test/flutter_test.dart';
import 'package:reminder/services/person_span_service.dart';

void main() {
  test('maps repeated PERSON words to ordered rune spans', () {
    final spans = PersonSpanService.locateWords('🙂李佩瑜和李佩瑜', ['李佩瑜', '李佩瑜']);

    expect(spans.map((span) => [span.start, span.end]), [
      [1, 4],
      [5, 8],
    ]);
  });

  test('ignores a model word that is not in the transcript', () {
    final spans = PersonSpanService.locateWords('明天找李佩瑜', ['王小明']);
    expect(spans, isEmpty);
  });
}
