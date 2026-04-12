abstract class SttService {
  Future<String> transcribe(
    String audioFilePath, {
    required String languageCode,
  });

  Stream<String> streamPartial({required String languageCode});

  Future<void> stopStreaming() async {}
}
