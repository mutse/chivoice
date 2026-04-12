import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../services/api_proxy.dart';
import '../../services/stt/google_stt.dart';
import '../../services/stt/on_device_stt.dart';
import '../../services/stt/stt_service.dart';
import '../../services/stt/whisper_stt.dart';
import '../settings/settings_provider.dart';
import '../transcript/transcript_provider.dart';
import 'audio_recorder_service.dart';

enum RecordingStatus { idle, recording, processing, error }

class RecordingState {
  const RecordingState({
    this.status = RecordingStatus.idle,
    this.liveText = '',
    this.elapsedSeconds = 0,
    this.wordCount = 0,
    this.errorMessage,
  });

  final RecordingStatus status;
  final String liveText;
  final int elapsedSeconds;
  final int wordCount;
  final String? errorMessage;

  RecordingState copyWith({
    RecordingStatus? status,
    String? liveText,
    int? elapsedSeconds,
    int? wordCount,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RecordingState(
      status: status ?? this.status,
      liveText: liveText ?? this.liveText,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      wordCount: wordCount ?? this.wordCount,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

final audioRecorderServiceProvider = Provider<AudioRecorderService>(
  (ref) => AudioRecorderService(),
);

final apiProxyProvider = Provider<ApiProxy>((ref) {
  final settings = ref.watch(settingsProvider);
  return ApiProxy(proxyBaseUrl: settings.proxyUrl);
});

final sttServiceProvider = Provider<SttService>((ref) {
  final settings = ref.watch(settingsProvider);
  switch (settings.provider) {
    case SttProvider.onDevice:
      return OnDeviceStt();
    case SttProvider.google:
      return GoogleStt(apiProxy: ref.watch(apiProxyProvider));
    case SttProvider.whisper:
      return WhisperStt(apiProxy: ref.watch(apiProxyProvider));
  }
});

final recordingProvider = NotifierProvider<RecordingNotifier, RecordingState>(
  RecordingNotifier.new,
);

class RecordingNotifier extends Notifier<RecordingState> {
  Timer? _timer;
  StreamSubscription<String>? _partialSubscription;
  String? _recordingPath;

  @override
  RecordingState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _partialSubscription?.cancel();
    });
    return const RecordingState();
  }

  Future<void> startRecording() async {
    if (state.status == RecordingStatus.recording) {
      return;
    }

    final settings = ref.read(settingsProvider);
    final recorder = ref.read(audioRecorderServiceProvider);
    final stt = ref.read(sttServiceProvider);

    try {
      _recordingPath = await recorder.start(
        sampleRate: settings.sampleRate.value,
      );
      state = const RecordingState(status: RecordingStatus.recording);
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
      });
      _partialSubscription?.cancel();
      _partialSubscription = stt
          .streamPartial(languageCode: settings.languageCode)
          .listen(_applyPartial, onError: _handleError);
    } catch (error) {
      _handleError(error);
    }
  }

  Future<void> stopRecording() async {
    if (state.status != RecordingStatus.recording) {
      return;
    }

    _timer?.cancel();
    state = state.copyWith(
      status: RecordingStatus.processing,
      clearError: true,
    );

    final settings = ref.read(settingsProvider);
    final recorder = ref.read(audioRecorderServiceProvider);
    final stt = ref.read(sttServiceProvider);

    try {
      await stt.stopStreaming();
      final filePath = await recorder.stop() ?? _recordingPath;
      if (filePath == null) {
        throw const AudioRecorderException('No audio file was recorded.');
      }

      String text = state.liveText.trim();
      if (settings.provider != SttProvider.onDevice) {
        text = await stt.transcribe(
          filePath,
          languageCode: settings.languageCode,
        );
      }

      if (text.isEmpty) {
        throw const SpeechRecognitionException('No speech was detected.');
      }

      final cleaned = _formatText(text, settings.smartPunctuation);
      final entry = TranscriptEntry(
        id: const Uuid().v4(),
        text: cleaned,
        createdAt: DateTime.now(),
        languageCode: settings.languageCode,
        wordCount: _countWords(cleaned),
      );
      ref.read(transcriptProvider.notifier).add(entry);
      state = RecordingState(
        status: RecordingStatus.idle,
        liveText: cleaned,
        wordCount: entry.wordCount,
      );
    } catch (error) {
      if (settings.provider != SttProvider.onDevice) {
        await _fallbackToOnDevice(settings.languageCode);
        return;
      }
      _handleError(error);
    }
  }

  void clearMessage() {
    state = state.copyWith(clearError: true, status: RecordingStatus.idle);
  }

  void _applyPartial(String value) {
    final cleaned = _formatText(
      value,
      ref.read(settingsProvider).smartPunctuation,
    );
    state = state.copyWith(liveText: cleaned, wordCount: _countWords(cleaned));
  }

  Future<void> _fallbackToOnDevice(String languageCode) async {
    final fallback = OnDeviceStt();
    final text = await fallback.transcribe(
      _recordingPath ?? '',
      languageCode: languageCode,
    );
    if (text.isEmpty) {
      _handleError(
        const SttRemoteException(
          message:
              'Cloud transcription failed and no on-device fallback was available.',
        ),
      );
      return;
    }
    final cleaned = _formatText(
      text,
      ref.read(settingsProvider).smartPunctuation,
    );
    final entry = TranscriptEntry(
      id: const Uuid().v4(),
      text: cleaned,
      createdAt: DateTime.now(),
      languageCode: languageCode,
      wordCount: _countWords(cleaned),
    );
    ref.read(transcriptProvider.notifier).add(entry);
    state = RecordingState(
      status: RecordingStatus.idle,
      liveText: cleaned,
      wordCount: entry.wordCount,
      errorMessage:
          'Cloud transcription failed. Switched to on-device fallback.',
    );
  }

  void _handleError(Object error) {
    _timer?.cancel();
    state = state.copyWith(
      status: RecordingStatus.error,
      errorMessage: error.toString(),
    );
  }

  static String _formatText(String value, bool punctuation) {
    final trimmed = value.trim();
    if (!punctuation || trimmed.isEmpty) {
      return trimmed;
    }
    final normalized = '${trimmed[0].toUpperCase()}${trimmed.substring(1)}'
        .replaceAll(' ,', ',');
    return normalized.endsWith('.') ? normalized : '$normalized.';
  }

  static int _countWords(String value) {
    if (value.trim().isEmpty) {
      return 0;
    }
    return value.trim().split(RegExp(r'\s+')).length;
  }
}
