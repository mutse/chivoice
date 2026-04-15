import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:voxa/services/stt/on_device_stt.dart';

class _FakeSpeechToText extends SpeechToText {
  _FakeSpeechToText() : super.withMethodChannel();

  SpeechResultListener? _onResult;
  SpeechStatusListener? _onStatus;

  @override
  Future<bool> initialize({
    SpeechErrorListener? onError,
    SpeechStatusListener? onStatus,
    debugLogging = false,
    Duration finalTimeout = SpeechToText.defaultFinalTimeout,
    List<SpeechConfigOption>? options,
  }) async {
    _onStatus = onStatus;
    return true;
  }

  @override
  Future listen({
    SpeechResultListener? onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
    SpeechSoundLevelChange? onSoundLevelChange,
    cancelOnError = false,
    partialResults = true,
    onDevice = false,
    ListenMode listenMode = ListenMode.confirmation,
    sampleRate = 0,
    SpeechListenOptions? listenOptions,
  }) async {
    _onResult = onResult;
  }

  @override
  Future<void> stop() async {
    Future<void>.delayed(const Duration(milliseconds: 20), () {
      _onResult?.call(
        SpeechRecognitionResult(const [
          SpeechRecognitionWords('final fallback text', null, 0.9),
        ], true),
      );
      _onStatus?.call(SpeechToText.doneStatus);
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('waits for final on-device result when stopping', () async {
    final service = OnDeviceStt(
      speech: _FakeSpeechToText(),
      finalTimeout: const Duration(milliseconds: 10),
      stopTimeout: const Duration(milliseconds: 100),
    );
    final partials = <String>[];

    final subscription = service
        .streamPartial(languageCode: 'en-US')
        .listen(partials.add);
    addTearDown(subscription.cancel);

    await Future<void>.delayed(Duration.zero);
    await service.stopStreaming();
    await Future<void>.delayed(Duration.zero);

    expect(partials, ['final fallback text']);
    expect(
      await service.transcribe('/tmp/ignored.m4a', languageCode: 'en-US'),
      'final fallback text',
    );
  });
}
