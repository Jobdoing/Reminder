import 'stt_service.dart';

class StubSttService implements SttService {
  StubSttService({
    this.scriptedPartials = const [],
    this.finalText = '',
  });

  final List<String> scriptedPartials;
  final String finalText;

  @override
  bool get isReady => true;

  @override
  Future<void> init() async {}

  @override
  Future<Stream<String>> start() async =>
      Stream<String>.fromIterable(scriptedPartials);

  @override
  Future<String> stop() async => finalText;
}
