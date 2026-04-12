import 'dart:async';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioRecorderService {
  AudioRecorderService({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  Stream<double> get amplitudeStream => _amplitudeController.stream;
  final StreamController<double> _amplitudeController =
      StreamController<double>.broadcast();
  StreamSubscription<Amplitude>? _amplitudeSubscription;

  Future<String> start({required int sampleRate}) async {
    if (!await _recorder.hasPermission()) {
      throw const AudioRecorderException('Microphone permission denied.');
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voxa_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );

    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 120))
        .listen((amp) {
          final normalized = ((amp.current + 45) / 45).clamp(0.0, 1.0);
          _amplitudeController.add(normalized);
        });

    return path;
  }

  Future<String?> stop() async {
    await _amplitudeSubscription?.cancel();
    _amplitudeController.add(0);
    return _recorder.stop();
  }

  Future<void> dispose() async {
    await _amplitudeSubscription?.cancel();
    await _amplitudeController.close();
    await _recorder.dispose();
  }
}

class AudioRecorderException implements Exception {
  const AudioRecorderException(this.message);
  final String message;

  @override
  String toString() => message;
}
