import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'stt_service.dart';

class OnDeviceStt implements SttService {
  OnDeviceStt({
    SpeechToText? speech,
    Duration finalTimeout = const Duration(milliseconds: 350),
    Duration stopTimeout = const Duration(milliseconds: 500),
  }) : _speech = speech ?? SpeechToText(),
       _finalTimeout = finalTimeout,
       _stopTimeout = stopTimeout;

  final SpeechToText _speech;
  final Duration _finalTimeout;
  final Duration _stopTimeout;
  final StreamController<String> _partials =
      StreamController<String>.broadcast();
  String _latest = '';
  Completer<void>? _sessionDone;

  @override
  Stream<String> streamPartial({required String languageCode}) async* {
    _sessionDone = Completer<void>();
    final available = await _speech.initialize(
      finalTimeout: _finalTimeout,
      onError: _handleSpeechError,
      onStatus: _handleStatus,
    );
    if (!available) {
      _completeSession();
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
    if (result.finalResult) {
      _completeSession();
    }
  }

  @override
  Future<String> transcribe(
    String audioFilePath, {
    required String languageCode,
  }) async {
    return _latest.trim();
  }

  @override
  Future<void> stopStreaming() async {
    await _speech.stop();
    final sessionDone = _sessionDone;
    if (sessionDone == null || sessionDone.isCompleted) {
      return;
    }
    try {
      await sessionDone.future.timeout(_stopTimeout);
    } on TimeoutException {
      _completeSession();
    }
  }

  void _handleSpeechError(SpeechRecognitionError error) {
    _completeSession();
    _partials.addError(SpeechRecognitionException(error.errorMsg));
  }

  void _handleStatus(String status) {
    if (status == SpeechToText.doneStatus) {
      _completeSession();
    }
  }

  void _completeSession() {
    final sessionDone = _sessionDone;
    if (sessionDone != null && !sessionDone.isCompleted) {
      sessionDone.complete();
    }
  }
}

class SpeechRecognitionException implements Exception {
  const SpeechRecognitionException(this.message);
  final String message;

  @override
  String toString() => message;
}
