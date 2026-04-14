# Voxa — Flutter Voice-to-Text App: Codex Spec

## Overview

Voxa is a cross-platform Flutter application that records audio via the device microphone, transcribes it in real time using on-device speech recognition, optionally refines the transcript with a cloud AI provider (Groq Whisper, Google Speech-to-Text, or Azure/AWS), and lets the user export the result as plain text, PDF, or a share-sheet file. The UI follows the dark-themed, purple-accented design shown in the approved mockup.

---

## Project structure

```
voxa/
  lib/
    main.dart
    app.dart                        # MaterialApp, theme, GoRouter setup
    features/
      recording/
        recording_page.dart         # Live tab UI
        recording_provider.dart     # Riverpod notifier: RecordingState
        audio_recorder_service.dart # Wraps `record` package
        waveform_widget.dart        # Animated bar visualizer
        mic_button.dart             # Pulse-ring mic button widget
      transcript/
        transcript_provider.dart    # Holds current + history entries
        transcript_card.dart        # Single history card
        history_page.dart           # History tab UI
        export_sheet.dart           # Bottom sheet: TXT / PDF / Share
        export_service.dart         # File write + share logic
      settings/
        settings_page.dart          # Settings tab UI
        settings_provider.dart      # Riverpod: language, provider, rate, punct
      shared/
        theme.dart                  # ThemeData, color constants
        widgets/
          tab_bar.dart
    services/
      stt/
        stt_service.dart            # Abstract STT interface
        on_device_stt.dart          # speech_to_text implementation
        whisper_stt.dart            # Groq Whisper HTTP implementation
        google_stt.dart             # Google Speech-to-Text implementation
      api_proxy.dart                # Injects Authorization header; never stores key in app
  test/
    recording_provider_test.dart
    export_service_test.dart
    stt_mock_test.dart
  pubspec.yaml
  android/app/src/main/AndroidManifest.xml
  ios/Runner/Info.plist
```

---

## Dependencies (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter
  # Audio
  record: ^5.0.0
  # On-device STT
  speech_to_text: ^6.3.0
  # State management
  flutter_riverpod: ^2.5.0
  riverpod_annotation: ^2.3.0
  # HTTP
  dio: ^5.4.0
  # Local persistence
  hive_flutter: ^1.1.0
  # File I/O
  path_provider: ^2.1.0
  # Export & share
  share_plus: ^9.0.0
  pdf: ^3.10.0
  printing: ^5.12.0
  # Navigation
  go_router: ^13.0.0

dev_dependencies:
  build_runner: ^2.4.0
  riverpod_generator: ^2.3.0
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.0
```

---

## Platform permissions

### Android — `AndroidManifest.xml`

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
    android:maxSdkVersion="28"/>
```

### iOS — `Info.plist`

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Voxa needs microphone access to transcribe your speech.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Voxa uses on-device speech recognition to produce live transcripts.</string>
<key>UIFileSharingEnabled</key><true/>
<key>LSSupportsOpeningDocumentsInPlace</key><true/>
```

---

## State model

### `RecordingState`

```dart
enum RecordingStatus { idle, recording, processing, error }

@freezed
class RecordingState with _$RecordingState {
  const factory RecordingState({
    @Default(RecordingStatus.idle) RecordingStatus status,
    @Default('') String liveText,       // partial words during recording
    @Default(0) int elapsedSeconds,
    @Default(0) int wordCount,
    String? errorMessage,
  }) = _RecordingState;
}
```

### `TranscriptEntry`

```dart
@freezed
class TranscriptEntry with _$TranscriptEntry {
  const factory TranscriptEntry({
    required String id,
    required String text,
    required DateTime createdAt,
    required String languageCode,    // e.g. 'en-US'
    required int wordCount,
  }) = _TranscriptEntry;
}
```

### `SettingsState`

```dart
@freezed
class SettingsState with _$SettingsState {
  const factory SettingsState({
    @Default(SttProvider.whisper) SttProvider provider,
    @Default('en-US') String languageCode,
    @Default(SampleRate.k441) SampleRate sampleRate,
    @Default(true) bool smartPunctuation,
  }) = _SettingsState;
}

enum SttProvider { whisper, google, onDevice }
enum SampleRate { k16, k441, k48 }
```

---

## Service interfaces

### `SttService` (abstract)

```dart
abstract class SttService {
  /// Returns the final transcript for [audioFilePath].
  Future<String> transcribe(String audioFilePath, {required String languageCode});

  /// Emits partial words in real time. Completes when recording stops.
  Stream<String> streamPartial();
}
```

Implementations: `OnDeviceStt`, `WhisperStt`, `GoogleStt`.
The active implementation is resolved via a Riverpod `Provider` that reads `settingsProvider`.

### `WhisperStt`

- `POST https://api.groq.com/openai/v1/audio/transcriptions`
- Multipart form: `file` (`.m4a`), `model: whisper-large-v3`, `language: <code>`
- Authorization header uses the Groq API key configured in app settings.

### `ExportService`

```dart
abstract class ExportService {
  Future<void> shareText(String text);
  Future<File> saveTxt(String text);
  Future<void> exportPdf(TranscriptEntry entry);
}
```

See export implementation details in the [Export section](#export-flows) below.

---

## Feature: recording flow

1. User taps mic button → `RecordingNotifier.startRecording()`.
2. `AudioRecorderService.start()` writes to a temp `.m4a` file.
3. `OnDeviceStt.streamPartial()` feeds mic audio to the OS STT engine; partial results update `liveText` every ~300 ms.
4. Waveform widget reads amplitude from `AudioRecorderService.amplitudeStream` and scales bar heights.
5. Timer increments `elapsedSeconds` each second.
6. User taps stop → `AudioRecorderService.stop()` returns the file path.
7. If provider is `whisper` or `google`, `SttService.transcribe(path)` is called; a loading indicator replaces the cursor.
8. Final text replaces `liveText`; a `TranscriptEntry` is appended to history and persisted via Hive.

**Error handling**: network errors surface as a dismissible banner; on-device fallback is offered automatically if the cloud call fails.

---

## Feature: waveform widget

```dart
class WaveformWidget extends StatefulWidget {
  final Stream<double> amplitudeStream; // 0.0–1.0 normalised
  final int barCount;                   // default 30
  final Color activeColor;
}
```

- Renders `barCount` vertical bars using `AnimatedContainer` height transitions (duration 80 ms).
- Each bar height = `maxHeight * amplitude * randomFactor(i)` where `randomFactor` is seeded per-bar to give organic variation.
- When idle, all bars animate to `minHeight` (4 px).

---

## Feature: history tab

- Displays a `ListView` of `TranscriptEntry` items, newest first.
- Each card shows: relative time label, language badge, word count badge, and the first 120 characters of the transcript.
- Swipe-to-delete triggers a confirmation snackbar with undo.
- Tap opens a detail bottom sheet with full text and export options.

---

## Export flows

### Plain text

```dart
Future<File> saveTxt(String text) async {
  final dir = await getApplicationDocumentsDirectory();
  final name = 'transcript_${_timestamp()}.txt';
  return File('${dir.path}/$name').writeAsString(text);
}
```

### Share sheet

```dart
Future<void> shareText(String text) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/transcript.txt')..writeAsStringSync(text);
  await Share.shareXFiles([XFile(file.path)], subject: 'Transcript');
}
```

### PDF

```dart
Future<void> exportPdf(TranscriptEntry entry) async {
  final doc = pw.Document();
  doc.addPage(pw.Page(
    margin: const pw.EdgeInsets.all(40),
    build: (_) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Transcript', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text(
          '${entry.createdAt.toLocal()} · ${entry.languageCode} · ${entry.wordCount} words',
          style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
        ),
        pw.Divider(height: 24),
        pw.Text(entry.text, style: const pw.TextStyle(fontSize: 13, lineSpacing: 4)),
      ],
    ),
  ));
  await Printing.layoutPdf(onLayout: (_) async => doc.save());
}
```

### Export bottom sheet (UI)

The bottom sheet (`ExportSheet`) presents three `ListTile` options: Share, Save as PDF, Save to files. It is triggered from both the live tab action bar and the history detail sheet.

---

## Settings tab

| Setting | Widget | Values |
|---|---|---|
| AI provider | Custom radio list | Groq Whisper · Google · On-device |
| Language | Dropdown | EN · ZH · JA · FR · ES · DE (maps to BCP-47 codes) |
| Sample rate | Slider (3 steps) | 16 kHz · 44.1 kHz · 48 kHz |
| Smart punctuation | Toggle switch | on / off |

Settings are persisted in Hive box `settings` under string keys matching `SettingsState` field names.

---

## Theme

```dart
// lib/features/shared/theme.dart
const kPurple400 = Color(0xFF7F77DD);
const kPurple600 = Color(0xFF534AB7);
const kPurple800 = Color(0xFF3C3489);
const kSurface    = Color(0xFF1A1A2E);
const kSurface2   = Color(0xFF12122A);
const kSurface3   = Color(0xFF2A2A45);

ThemeData voxaTheme() => ThemeData(
  colorScheme: ColorScheme.dark(
    primary: kPurple400,
    secondary: kPurple600,
    surface: kSurface,
  ),
  scaffoldBackgroundColor: kSurface,
  useMaterial3: true,
);
```

---

## Routing (`go_router`)

```
/             → RecordingPage  (Live tab default)
/history      → HistoryPage
/settings     → SettingsPage
/transcript/:id → TranscriptDetailSheet (shown as bottom sheet)
```

---

## Testing requirements

| Test file | What to cover |
|---|---|
| `recording_provider_test.dart` | State transitions: idle → recording → processing → idle; error path |
| `export_service_test.dart` | `saveTxt` writes correct content; `shareText` constructs correct `XFile` |
| `stt_mock_test.dart` | `WhisperStt` sends correct multipart fields; handles 401 / 500 responses |

Use `mocktail` to mock `SttService` and `ExportService` in widget tests.

---

## Out of scope (v1)

- Real-time streaming to Whisper (WebSocket) — deferred to v2.
- Speaker diarisation.
- In-app audio playback of recordings.
- Cloud sync / user accounts.
