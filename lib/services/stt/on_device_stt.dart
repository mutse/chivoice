import 'dart:async';

import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'stt_service.dart';

class OnDeviceStt implements SttService {
  OnDeviceStt({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  final StreamController<String> _partials =
      StreamController<String>.broadcast();
  String _latest = '';

  @override
  Stream<String> streamPartial({required String languageCode}) async* {
    final available = await _speech.initialize();
    if (!available) {
      throw const SpeechRecognitionException(
        'Speech recognition is unavailable on this device.',
      );
    }

    _latest = '';
    await _speech.listen(
      localeId: languageCode,
      onResult: _onResult,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
      ),
    );
    yield* _partials.stream;
  }

  void _onResult(SpeechRecognitionResult result) {
    _latest = result.recognizedWords;
    _partials.add(_latest);
  }

  @override
  Future<String> transcribe(
    String audioFilePath, {
    required String languageCode,
  }) async {
    return _latest.trim();
  }

  @override
  Future<void> stopStreaming() => _speech.stop();
}

class SpeechRecognitionException implements Exception {
  const SpeechRecognitionException(this.message);
  final String message;

  @override
  String toString() => message;
}
