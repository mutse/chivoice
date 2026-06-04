import 'dart:io';

import 'package:chivoice/features/settings/settings_provider.dart';
import 'package:chivoice/services/api_proxy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('chivoice_settings_test');
    Hive.init(dir.path);
    if (!Hive.isBoxOpen('settings')) {
      await Hive.openBox<dynamic>('settings');
    }
  });

  setUp(() async {
    await Hive.box<dynamic>('settings').clear();
  });

  test('migrates legacy groq fields into generic cloud stt settings', () {
    final state = SettingsState.fromMap({
      'provider': 'whisper',
      'groqApiKey': 'gsk_legacy',
      'groqModel': 'largeV3Turbo',
    });

    expect(state.sttPreset, SttPreset.groq);
    expect(state.sttApiKey, 'gsk_legacy');
    expect(state.sttBaseUrl, groqOpenAiCompatibleBaseUrl);
    expect(state.sttModelId, 'whisper-large-v3-turbo');
  });

  test('persists domestic-compatible cloud stt settings', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(settingsProvider.notifier);
    notifier.updateSttPreset(SttPreset.domesticCompatible);
    notifier.updateSttBaseUrl('https://stt.example.cn/v1');
    notifier.updateSttApiKey('cn_key');
    notifier.updateSttModelId('sensevoice-v1');

    final state = container.read(settingsProvider);
    final box = Hive.box<dynamic>('settings');

    expect(state.sttPreset, SttPreset.domesticCompatible);
    expect(state.sttBaseUrl, 'https://stt.example.cn/v1');
    expect(state.sttApiKey, 'cn_key');
    expect(state.sttModelId, 'sensevoice-v1');

    expect(box.get('sttPreset'), 'domesticCompatible');
    expect(box.get('sttBaseUrl'), 'https://stt.example.cn/v1');
    expect(box.get('sttApiKey'), 'cn_key');
    expect(box.get('sttModelId'), 'sensevoice-v1');
  });
}
