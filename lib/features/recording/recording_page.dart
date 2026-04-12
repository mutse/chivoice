import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_provider.dart';
import '../shared/theme.dart';
import '../transcript/export_service.dart';
import '../transcript/export_sheet.dart';
import '../transcript/transcript_provider.dart';
import 'mic_button.dart';
import 'recording_provider.dart';
import 'waveform_widget.dart';

class RecordingPage extends ConsumerWidget {
  const RecordingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recording = ref.watch(recordingProvider);
    final recorder = ref.watch(audioRecorderServiceProvider);

    ref.listen<RecordingState>(recordingProvider, (previous, next) {
      final message = next.errorMessage;
      if (message != null && message.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            action: SnackBarAction(
              label: 'Dismiss',
              onPressed: () =>
                  ref.read(recordingProvider.notifier).clearMessage(),
            ),
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voxa'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: recording.liveText.trim().isEmpty
                ? null
                : () {
                    final entry = TranscriptEntry(
                      id: 'live',
                      text: recording.liveText,
                      createdAt: DateTime.now(),
                      languageCode: ref.read(settingsProvider).languageCode,
                      wordCount: recording.wordCount,
                    );
                    showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: kSurface2,
                      builder: (context) => ExportSheet(
                        entry: entry,
                        exportService: ref.read(exportServiceProvider),
                      ),
                    );
                  },
            icon: const Icon(Icons.ios_share_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  colors: [kSurface3, kSurface2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Live Transcript',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    recording.liveText.isEmpty
                        ? 'Tap the microphone and start speaking.'
                        : recording.liveText,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _Metric(
                        label: 'Elapsed',
                        value: '${recording.elapsedSeconds}s',
                      ),
                      const SizedBox(width: 12),
                      _Metric(label: 'Words', value: '${recording.wordCount}'),
                      const Spacer(),
                      if (recording.status == RecordingStatus.processing)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Center(
              child: WaveformWidget(
                amplitudeStream: recorder.amplitudeStream,
                activeColor: kPurple400,
              ),
            ),
            const SizedBox(height: 28),
            Center(
              child: MicButton(
                isRecording: recording.status == RecordingStatus.recording,
                onPressed: () {
                  final notifier = ref.read(recordingProvider.notifier);
                  if (recording.status == RecordingStatus.recording) {
                    notifier.stopRecording();
                  } else {
                    notifier.startRecording();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
