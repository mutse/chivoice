import 'dart:async';

import 'package:chivoice/features/recording/audio_recorder_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

class _SingleListenAmplitudeRecorder extends AudioRecorder {
  final StreamController<Amplitude> _amplitudes = StreamController<Amplitude>();

  int amplitudeStreamRequests = 0;
  int starts = 0;
  int stops = 0;
  bool disposed = false;
  final List<RecordConfig> startConfigs = [];
  final List<String> startPaths = [];

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    starts++;
    startConfigs.add(config);
    startPaths.add(path);
  }

  @override
  Stream<Amplitude> onAmplitudeChanged(Duration interval) {
    amplitudeStreamRequests++;
    return _amplitudes.stream;
  }

  @override
  Future<String?> stop() async {
    stops++;
    return '/tmp/fake.m4a';
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _amplitudes.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          if (call.method == 'getTemporaryDirectory') {
            return '/tmp';
          }
          return null;
        });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  test(
    'reuses the record amplitude stream subscription across recordings',
    () async {
      final recorder = _SingleListenAmplitudeRecorder();
      final service = AudioRecorderService(recorder: recorder);
      addTearDown(service.dispose);

      await service.start(sampleRate: 16000);
      await service.stop();
      await service.start(sampleRate: 16000);
      await service.stop();

      expect(recorder.starts, 2);
      expect(recorder.stops, 2);
      expect(recorder.amplitudeStreamRequests, 1);
    },
  );

  test('forwards configured sample rate and uses chivoice file prefix',
      () async {
    final recorder = _SingleListenAmplitudeRecorder();
    final service = AudioRecorderService(recorder: recorder);
    addTearDown(service.dispose);

    await service.start(sampleRate: 48000);
    await service.stop();

    expect(recorder.startConfigs.single.sampleRate, 48000);
    expect(recorder.startConfigs.single.encoder, AudioEncoder.aacLc);
    expect(recorder.startPaths.single, contains('/chivoice_'));
    expect(recorder.startPaths.single, endsWith('.m4a'));
  });
}
