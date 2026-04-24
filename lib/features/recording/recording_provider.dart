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
    this.transcriptId,
    this.errorMessage,
  });

  final RecordingStatus status;
  final String liveText;
  final int elapsedSeconds;
  final int wordCount;
  final String? transcriptId;
  final String? errorMessage;

  RecordingState copyWith({
    RecordingStatus? status,
    String? liveText,
    int? elapsedSeconds,
    int? wordCount,
    String? transcriptId,
    String? errorMessage,
    bool clearError = false,
    bool clearTranscriptId = false,
  }) {
    return RecordingState(
      status: status ?? this.status,
      liveText: liveText ?? this.liveText,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      wordCount: wordCount ?? this.wordCount,
      transcriptId: clearTranscriptId
          ? null
          : transcriptId ?? this.transcriptId,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

final audioRecorderServiceProvider = Provider<AudioRecorderService>(
  (ref) => AudioRecorderService(),
);

final googleApiProxyProvider = Provider<ApiProxy>((ref) {
  final settings = ref.watch(settingsProvider);
  return ApiProxy(baseUrl: settings.proxyUrl);
});

final groqApiProxyProvider = Provider<ApiProxy>((ref) {
  final settings = ref.watch(settingsProvider);
  final headers = <String, String>{};
  if (settings.groqApiKey.isNotEmpty) {
    headers['Authorization'] = 'Bearer ${settings.groqApiKey}';
  }
  return ApiProxy(baseUrl: groqOpenAiCompatibleBaseUrl, headers: headers);
});

final liveSttProvider = Provider<SttService>((ref) => OnDeviceStt());

final sttServiceProvider = Provider<SttService>((ref) {
  final settings = ref.watch(settingsProvider);
  switch (settings.provider) {
    case SttProvider.onDevice:
      return ref.watch(liveSttProvider);
    case SttProvider.google:
      return GoogleStt(apiProxy: ref.watch(googleApiProxyProvider));
    case SttProvider.whisper:
      return WhisperStt(
        apiProxy: ref.watch(groqApiProxyProvider),
        model: settings.groqModel,
      );
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
    final liveStt = ref.read(liveSttProvider);

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
      _partialSubscription = liveStt
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
    final liveStt = ref.read(liveSttProvider);
    final stt = ref.read(sttServiceProvider);

    try {
      await liveStt.stopStreaming();
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

      final cleaned = _formatText(text, settings, finalize: true);
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
        transcriptId: entry.id,
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

  void updateDraftText(String value) {
    final cleaned = value.trimRight();
    state = state.copyWith(
      liveText: cleaned,
      wordCount: _countWords(cleaned),
      clearError: true,
    );

    final transcriptId = state.transcriptId;
    if (transcriptId == null || cleaned.trim().isEmpty) {
      return;
    }

    final entry = ref.read(transcriptByIdProvider(transcriptId));
    if (entry == null) {
      return;
    }
    ref
        .read(transcriptProvider.notifier)
        .update(entry.copyWith(text: cleaned, wordCount: _countWords(cleaned)));
  }

  void deleteCurrentDraft() {
    final transcriptId = state.transcriptId;
    if (transcriptId != null) {
      ref.read(transcriptProvider.notifier).delete(transcriptId);
    }
    state = const RecordingState();
  }

  void _applyPartial(String value) {
    final cleaned = _formatText(value, ref.read(settingsProvider));
    state = state.copyWith(liveText: cleaned, wordCount: _countWords(cleaned));
  }

  Future<void> _fallbackToOnDevice(String languageCode) async {
    final text = state.liveText.trim();
    if (text.isEmpty) {
      _handleError(
        const SttRemoteException(
          message:
              'Cloud transcription failed and no on-device fallback was available.',
        ),
      );
      return;
    }
    final settings = ref.read(settingsProvider);
    final cleaned = _formatText(text, settings, finalize: true);
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
      transcriptId: entry.id,
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

  static String _formatText(
    String value,
    SettingsState settings, {
    bool finalize = false,
  }) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }

    var normalized = trimmed
        .replaceAll(RegExp(r'\s+([,.!?])'), r'$1')
        .replaceAll(RegExp(r'\s+([，。！？；：])'), r'$1');

    final usesCjk = _usesCjkFormatting(settings.languageCode, normalized);
    if (!usesCjk) {
      normalized = '${normalized[0].toUpperCase()}${normalized.substring(1)}';
    }

    if (!settings.smartPunctuation || !finalize) {
      return normalized;
    }

    if (_hasTerminalPunctuation(normalized)) {
      return normalized;
    }

    final terminal = _chooseTerminalPunctuation(normalized, settings, usesCjk);
    return '$normalized$terminal';
  }

  static int _countWords(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 0;
    }

    final hanCount = RegExp(r'[\u4E00-\u9FFF]').allMatches(trimmed).length;
    if (hanCount > 0 && !trimmed.contains(RegExp(r'\s'))) {
      return hanCount;
    }

    return trimmed.split(RegExp(r'\s+')).length;
  }

  static bool _usesCjkFormatting(String languageCode, String value) {
    return languageCode.startsWith('zh') ||
        languageCode.startsWith('ja') ||
        RegExp(r'[\u3040-\u30FF\u4E00-\u9FFF]').hasMatch(value);
  }

  static bool _hasTerminalPunctuation(String value) {
    return value.endsWith('.') ||
        value.endsWith('!') ||
        value.endsWith('?') ||
        value.endsWith('...') ||
        value.endsWith('。') ||
        value.endsWith('！') ||
        value.endsWith('？') ||
        value.endsWith('……');
  }

  static String _chooseTerminalPunctuation(
    String value,
    SettingsState settings,
    bool usesCjk,
  ) {
    if (_looksLikeQuestion(value) && settings.questionStrength >= 0.4) {
      return usesCjk ? '？' : '?';
    }
    if (_looksExcited(value) && settings.exclamationStrength >= 0.4) {
      return usesCjk ? '！' : '!';
    }
    if (value.length > 42 && settings.ellipsisStrength >= 0.7) {
      return usesCjk ? '……' : '...';
    }
    if (settings.periodStrength <= 0.2) {
      return '';
    }
    return usesCjk ? '。' : '.';
  }

  static bool _looksLikeQuestion(String value) {
    final lower = value.toLowerCase();
    return RegExp(
      r'(吗|么|呢|何时|为什么|怎么|是否|是不是|能不能|可不可以|who|what|when|where|why|how|can|should)',
      caseSensitive: false,
    ).hasMatch(lower);
  }

  static bool _looksExcited(String value) {
    final lower = value.toLowerCase();
    return RegExp(
      r'(太好了|真棒|厉害|赶紧|快点|wow|amazing|great|awesome)',
      caseSensitive: false,
    ).hasMatch(lower);
  }
}
