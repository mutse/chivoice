import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

enum SttProvider { whisper, google, onDevice }

enum SampleRate {
  k16(16000, '16 kHz'),
  k441(44100, '44.1 kHz'),
  k48(48000, '48 kHz');

  const SampleRate(this.value, this.label);
  final int value;
  final String label;
}

class SettingsState {
  const SettingsState({
    this.provider = SttProvider.whisper,
    this.languageCode = 'en-US',
    this.sampleRate = SampleRate.k441,
    this.smartPunctuation = true,
    this.groqApiKey = '',
    this.proxyUrl = '',
  });

  final SttProvider provider;
  final String languageCode;
  final SampleRate sampleRate;
  final bool smartPunctuation;
  final String groqApiKey;
  final String proxyUrl;

  SettingsState copyWith({
    SttProvider? provider,
    String? languageCode,
    SampleRate? sampleRate,
    bool? smartPunctuation,
    String? groqApiKey,
    String? proxyUrl,
  }) {
    return SettingsState(
      provider: provider ?? this.provider,
      languageCode: languageCode ?? this.languageCode,
      sampleRate: sampleRate ?? this.sampleRate,
      smartPunctuation: smartPunctuation ?? this.smartPunctuation,
      groqApiKey: groqApiKey ?? this.groqApiKey,
      proxyUrl: proxyUrl ?? this.proxyUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'provider': provider.name,
      'languageCode': languageCode,
      'sampleRate': sampleRate.name,
      'smartPunctuation': smartPunctuation,
      'groqApiKey': groqApiKey,
      'proxyUrl': proxyUrl,
    };
  }

  factory SettingsState.fromMap(Map<dynamic, dynamic> map) {
    return SettingsState(
      provider: SttProvider.values.firstWhere(
        (value) => value.name == map['provider'],
        orElse: () => SttProvider.whisper,
      ),
      languageCode: map['languageCode'] as String? ?? 'en-US',
      sampleRate: SampleRate.values.firstWhere(
        (value) => value.name == map['sampleRate'],
        orElse: () => SampleRate.k441,
      ),
      smartPunctuation: map['smartPunctuation'] as bool? ?? true,
      groqApiKey: map['groqApiKey'] as String? ?? '',
      proxyUrl: map['proxyUrl'] as String? ?? '',
    );
  }
}

final settingsBoxProvider = Provider<Box<dynamic>>(
  (ref) => Hive.box<dynamic>('settings'),
);

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    final box = ref.read(settingsBoxProvider);
    final legacyState = box.get('state');
    if (legacyState is Map) {
      final migrated = SettingsState.fromMap(legacyState);
      _persistFields(migrated);
      box.delete('state');
      return migrated;
    }
    return SettingsState(
      provider: SttProvider.values.firstWhere(
        (value) => value.name == box.get('provider'),
        orElse: () => SttProvider.whisper,
      ),
      languageCode: box.get('languageCode') as String? ?? 'en-US',
      sampleRate: SampleRate.values.firstWhere(
        (value) => value.name == box.get('sampleRate'),
        orElse: () => SampleRate.k441,
      ),
      smartPunctuation: box.get('smartPunctuation') as bool? ?? true,
      groqApiKey: box.get('groqApiKey') as String? ?? '',
      proxyUrl: box.get('proxyUrl') as String? ?? '',
    );
  }

  void updateProvider(SttProvider provider) {
    _save(state.copyWith(provider: provider));
  }

  void updateLanguage(String code) {
    _save(state.copyWith(languageCode: code));
  }

  void updateSampleRate(SampleRate rate) {
    _save(state.copyWith(sampleRate: rate));
  }

  void toggleSmartPunctuation(bool value) {
    _save(state.copyWith(smartPunctuation: value));
  }

  void updateGroqApiKey(String value) {
    _save(state.copyWith(groqApiKey: value.trim()));
  }

  void updateProxyUrl(String value) {
    _save(state.copyWith(proxyUrl: value.trim()));
  }

  void _save(SettingsState next) {
    state = next;
    _persistFields(next);
  }

  void _persistFields(SettingsState next) {
    final box = ref.read(settingsBoxProvider);
    box.put('provider', next.provider.name);
    box.put('languageCode', next.languageCode);
    box.put('sampleRate', next.sampleRate.name);
    box.put('smartPunctuation', next.smartPunctuation);
    box.put('groqApiKey', next.groqApiKey);
    box.put('proxyUrl', next.proxyUrl);
  }
}

const languageOptions = <String, String>{
  'en-US': 'EN',
  'zh-CN': 'ZH',
  'ja-JP': 'JA',
  'fr-FR': 'FR',
  'es-ES': 'ES',
  'de-DE': 'DE',
};
