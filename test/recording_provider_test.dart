import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:voxa/features/recording/audio_recorder_service.dart';
import 'package:voxa/features/recording/recording_provider.dart';
import 'package:voxa/features/settings/settings_provider.dart';
import 'package:voxa/features/transcript/transcript_provider.dart';
import 'package:voxa/services/stt/stt_service.dart';

class _FakeRecorder extends AudioRecorderService {
  _FakeRecorder();

  final StreamController<double> _amplitude =
      StreamController<double>.broadcast();
  bool shouldFail = false;
  String stoppedPath = '/tmp/test.m4a';

  @override
  Stream<double> get amplitudeStream => _amplitude.stream;

  @override
  Future<String> start({required int sampleRate}) async {
    if (shouldFail) {
      throw const AudioRecorderException('boom');
    }
    _amplitude.add(0.7);
    return stoppedPath;
  }

  @override
  Future<String?> stop() async => stoppedPath;
}

class _FakeStt implements SttService {
  _FakeStt({this.finalText = 'hello world'});

  final String finalText;

  @override
  Stream<String> streamPartial({required String languageCode}) async* {
    yield 'hello world';
  }

  @override
  Future<String> transcribe(
    String audioFilePath, {
    required String languageCode,
  }) async {
    return finalText;
  }

  @override
  Future<void> stopStreaming() async {}
}

class _ThrowingPartialStt extends _FakeStt {
  bool streamRequested = false;

  @override
  Stream<String> streamPartial({required String languageCode}) async* {
    streamRequested = true;
    throw Exception('error_language_not_supported');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('voxa_hive_test');
    Hive.init(dir.path);
    if (!Hive.isBoxOpen('settings')) {
      await Hive.openBox<dynamic>('settings');
    }
    if (!Hive.isBoxOpen('transcripts')) {
      await Hive.openBox<dynamic>('transcripts');
    }
  });

  setUp(() async {
    await Hive.box<dynamic>('settings').clear();
    await Hive.box<dynamic>('transcripts').clear();
  });

  test('state transitions idle to recording to processing to idle', () async {
    final recorder = _FakeRecorder();
    final liveStt = _FakeStt(finalText: 'hello world');
    final stt = _FakeStt(finalText: 'hello from voxa');
    final container = ProviderContainer(
      overrides: [
        audioRecorderServiceProvider.overrideWithValue(recorder),
        liveSttProvider.overrideWithValue(liveStt),
        sttServiceProvider.overrideWithValue(stt),
      ],
    );
    addTearDown(container.dispose);
    container.read(settingsProvider.notifier).updateLanguage('en-US');

    await container.read(recordingProvider.notifier).startRecording();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(recordingProvider).status, RecordingStatus.recording);
    expect(container.read(recordingProvider).liveText, isEmpty);

    final stopFuture = container
        .read(recordingProvider.notifier)
        .stopRecording();
    expect(
      container.read(recordingProvider).status,
      RecordingStatus.processing,
    );

    await stopFuture;

    final state = container.read(recordingProvider);
    expect(state.status, RecordingStatus.idle);
    expect(state.liveText, 'Hello from voxa.');
    expect(container.read(transcriptProvider), isNotEmpty);
  });

  test(
    'cloud recording skips unsupported on-device partial recognition',
    () async {
      final recorder = _FakeRecorder();
      final liveStt = _ThrowingPartialStt();
      final stt = _FakeStt(finalText: '今天天气真好');
      final container = ProviderContainer(
        overrides: [
          audioRecorderServiceProvider.overrideWithValue(recorder),
          liveSttProvider.overrideWithValue(liveStt),
          sttServiceProvider.overrideWithValue(stt),
        ],
      );
      addTearDown(container.dispose);
      container.read(settingsProvider.notifier)
        ..updateProvider(SttProvider.whisper)
        ..updateLanguage('zh-CN');

      await container.read(recordingProvider.notifier).startRecording();
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(recordingProvider).status,
        RecordingStatus.recording,
      );
      expect(liveStt.streamRequested, isFalse);

      await container.read(recordingProvider.notifier).stopRecording();

      final state = container.read(recordingProvider);
      expect(state.status, RecordingStatus.idle);
      expect(state.liveText, '今天天气真好。');
    },
  );

  test('error path updates state', () async {
    final recorder = _FakeRecorder()..shouldFail = true;
    final container = ProviderContainer(
      overrides: [
        audioRecorderServiceProvider.overrideWithValue(recorder),
        liveSttProvider.overrideWithValue(_FakeStt()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(recordingProvider.notifier).startRecording();

    expect(container.read(recordingProvider).status, RecordingStatus.error);
    expect(container.read(recordingProvider).errorMessage, contains('boom'));
  });
}
