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
    this.proxyUrl = '',
  });

  final SttProvider provider;
  final String languageCode;
  final SampleRate sampleRate;
  final bool smartPunctuation;
  final String proxyUrl;

  SettingsState copyWith({
    SttProvider? provider,
    String? languageCode,
    SampleRate? sampleRate,
    bool? smartPunctuation,
    String? proxyUrl,
  }) {
    return SettingsState(
      provider: provider ?? this.provider,
      languageCode: languageCode ?? this.languageCode,
      sampleRate: sampleRate ?? this.sampleRate,
      smartPunctuation: smartPunctuation ?? this.smartPunctuation,
      proxyUrl: proxyUrl ?? this.proxyUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'provider': provider.name,
      'languageCode': languageCode,
      'sampleRate': sampleRate.name,
      'smartPunctuation': smartPunctuation,
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
    final stored = ref.read(settingsBoxProvider).get('state');
    if (stored is Map) {
      return SettingsState.fromMap(stored);
    }
    return const SettingsState();
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

  void updateProxyUrl(String value) {
    _save(state.copyWith(proxyUrl: value.trim()));
  }

  void _save(SettingsState next) {
    state = next;
    ref.read(settingsBoxProvider).put('state', next.toMap());
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
