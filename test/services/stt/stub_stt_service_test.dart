import 'package:flutter_test/flutter_test.dart';
import 'package:reminder/services/stt/stub_stt_service.dart';

void main() {
  test('stub emits scripted partials then returns final text', () async {
    final stt = StubSttService(
      scriptedPartials: ['明天', '明天下午', '明天下午看王醫師'],
      finalText: '明天下午看王醫師',
    );
    await stt.init();
    final stream = await stt.start();
    final seen = await stream.toList();
    expect(seen, ['明天', '明天下午', '明天下午看王醫師']);
    expect(await stt.stop(), '明天下午看王醫師');
  });
}
