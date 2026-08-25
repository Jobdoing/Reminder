abstract class SttService {
  bool get isReady;
  Future<void> init();

  /// Starts listening. Emits partial transcripts as they arrive.
  Future<Stream<String>> start();

  /// Stops listening and returns the final full transcript.
  Future<String> stop();
}
