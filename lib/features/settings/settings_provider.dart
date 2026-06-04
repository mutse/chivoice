import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../services/api_proxy.dart';
import '../../services/platform/ime_platform_bridge.dart';
import 'personal_lexicon.dart';

enum SttProvider { whisper, google, onDevice }

enum SttPreset {
  groq(
    'Groq',
    groqOpenAiCompatibleBaseUrl,
    'whisper-large-v3',
    'Groq Whisper 预设，继续兼容现有云端识别配置。',
    'https://api.groq.com/openai/v1',
    'whisper-large-v3',
  ),
  domesticCompatible(
    '国内兼容',
    '',
    '',
    '填写国内 OpenAI 兼容 STT 服务提供的地址、密钥和模型名。',
    'https://your-provider.cn/v1',
    '供应商要求的模型 ID',
  ),
  custom(
    '自定义',
    '',
    '',
    '适配任意 OpenAI 兼容 STT 服务。',
    'https://api.example.com/v1',
    'your-model-id',
  );

  const SttPreset(
    this.label,
    this.defaultBaseUrl,
    this.defaultModelId,
    this.description,
    this.baseUrlHint,
    this.modelHint,
  );

  final String label;
  final String defaultBaseUrl;
  final String defaultModelId;
  final String description;
  final String baseUrlHint;
  final String modelHint;
}

enum AiProvider {
  groq('Groq', 'https://api.groq.com/openai/v1', 'llama-3.3-70b-versatile'),
  openai('OpenAI', 'https://api.openai.com/v1', 'gpt-4o-mini'),
  deepseek('DeepSeek', 'https://api.deepseek.com/v1', 'deepseek-chat'),
  custom('自定义', '', '');

  const AiProvider(this.label, this.defaultBaseUrl, this.defaultModel);

  final String label;
  final String defaultBaseUrl;
  final String defaultModel;
}

enum AppSkin {
  bamboo('青竹', 0xFF48624B, 0xFF9EB38B),
  ink('烟墨', 0xFF45545A, 0xFF9AA8AF),
  amber('暖砂', 0xFF866341, 0xFFD7B487),
  pine('松影', 0xFF3F5B4A, 0xFF89A78D),
  frost('月白', 0xFF64808F, 0xFFC6D8E3),
  dusk('暮岚', 0xFF705A67, 0xFFC2A9B6);

  const AppSkin(this.label, this.primaryValue, this.secondaryValue);

  final String label;
  final int primaryValue;
  final int secondaryValue;
}

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
    this.languageCode = 'zh-CN',
    this.sampleRate = SampleRate.k441,
    this.smartPunctuation = true,
    this.sttPreset = SttPreset.groq,
    this.sttApiKey = '',
    this.sttBaseUrl = groqOpenAiCompatibleBaseUrl,
    this.sttModelId = 'whisper-large-v3',
    this.proxyUrl = '',
    this.periodStrength = 0.8,
    this.commaStrength = 0.55,
    this.questionStrength = 0.65,
    this.exclamationStrength = 0.45,
    this.ellipsisStrength = 0.25,
    this.syncPersonalLexicon = true,
    this.syncSettings = true,
    this.syncInputHabits = true,
    this.skin = AppSkin.bamboo,
    this.lastSyncAt,
    this.personalLexicon = const [],
    this.aiEnabled = true,
    this.aiProvider = AiProvider.groq,
    this.aiBaseUrl = 'https://api.groq.com/openai/v1',
    this.aiApiKey = '',
    this.aiModel = 'llama-3.3-70b-versatile',
  });

  final SttProvider provider;
  final String languageCode;
  final SampleRate sampleRate;
  final bool smartPunctuation;
  final SttPreset sttPreset;
  final String sttApiKey;
  final String sttBaseUrl;
  final String sttModelId;
  final String proxyUrl;
  final double periodStrength;
  final double commaStrength;
  final double questionStrength;
  final double exclamationStrength;
  final double ellipsisStrength;
  final bool syncPersonalLexicon;
  final bool syncSettings;
  final bool syncInputHabits;
  final AppSkin skin;
  final DateTime? lastSyncAt;
  final List<PersonalLexiconEntry> personalLexicon;
  final bool aiEnabled;
  final AiProvider aiProvider;
  final String aiBaseUrl;
  final String aiApiKey;
  final String aiModel;

  SettingsState copyWith({
    SttProvider? provider,
    String? languageCode,
    SampleRate? sampleRate,
    bool? smartPunctuation,
    SttPreset? sttPreset,
    String? sttApiKey,
    String? sttBaseUrl,
    String? sttModelId,
    String? proxyUrl,
    double? periodStrength,
    double? commaStrength,
    double? questionStrength,
    double? exclamationStrength,
    double? ellipsisStrength,
    bool? syncPersonalLexicon,
    bool? syncSettings,
    bool? syncInputHabits,
    AppSkin? skin,
    DateTime? lastSyncAt,
    List<PersonalLexiconEntry>? personalLexicon,
    bool? aiEnabled,
    AiProvider? aiProvider,
    String? aiBaseUrl,
    String? aiApiKey,
    String? aiModel,
    bool clearLastSyncAt = false,
  }) {
    return SettingsState(
      provider: provider ?? this.provider,
      languageCode: languageCode ?? this.languageCode,
      sampleRate: sampleRate ?? this.sampleRate,
      smartPunctuation: smartPunctuation ?? this.smartPunctuation,
      sttPreset: sttPreset ?? this.sttPreset,
      sttApiKey: sttApiKey ?? this.sttApiKey,
      sttBaseUrl: sttBaseUrl ?? this.sttBaseUrl,
      sttModelId: sttModelId ?? this.sttModelId,
      proxyUrl: proxyUrl ?? this.proxyUrl,
      periodStrength: periodStrength ?? this.periodStrength,
      commaStrength: commaStrength ?? this.commaStrength,
      questionStrength: questionStrength ?? this.questionStrength,
      exclamationStrength: exclamationStrength ?? this.exclamationStrength,
      ellipsisStrength: ellipsisStrength ?? this.ellipsisStrength,
      syncPersonalLexicon: syncPersonalLexicon ?? this.syncPersonalLexicon,
      syncSettings: syncSettings ?? this.syncSettings,
      syncInputHabits: syncInputHabits ?? this.syncInputHabits,
      skin: skin ?? this.skin,
      lastSyncAt: clearLastSyncAt ? null : lastSyncAt ?? this.lastSyncAt,
      personalLexicon: personalLexicon ?? this.personalLexicon,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      aiProvider: aiProvider ?? this.aiProvider,
      aiBaseUrl: aiBaseUrl ?? this.aiBaseUrl,
      aiApiKey: aiApiKey ?? this.aiApiKey,
      aiModel: aiModel ?? this.aiModel,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'provider': provider.name,
      'languageCode': languageCode,
      'sampleRate': sampleRate.name,
      'smartPunctuation': smartPunctuation,
      'sttPreset': sttPreset.name,
      'sttApiKey': sttApiKey,
      'sttBaseUrl': sttBaseUrl,
      'sttModelId': sttModelId,
      'proxyUrl': proxyUrl,
      'periodStrength': periodStrength,
      'commaStrength': commaStrength,
      'questionStrength': questionStrength,
      'exclamationStrength': exclamationStrength,
      'ellipsisStrength': ellipsisStrength,
      'syncPersonalLexicon': syncPersonalLexicon,
      'syncSettings': syncSettings,
      'syncInputHabits': syncInputHabits,
      'skin': skin.name,
      'lastSyncAt': lastSyncAt?.toIso8601String(),
      'personalLexicon': personalLexicon.map((entry) => entry.toMap()).toList(),
      'aiEnabled': aiEnabled,
      'aiProvider': aiProvider.name,
      'aiBaseUrl': aiBaseUrl,
      'aiApiKey': aiApiKey,
      'aiModel': aiModel,
    };
  }

  factory SettingsState.fromMap(Map<dynamic, dynamic> map) {
    final sttPreset = _readSttPreset(map);
    return SettingsState(
      provider: SttProvider.values.firstWhere(
        (value) => value.name == map['provider'],
        orElse: () => SttProvider.whisper,
      ),
      languageCode: map['languageCode'] as String? ?? 'zh-CN',
      sampleRate: SampleRate.values.firstWhere(
        (value) => value.name == map['sampleRate'],
        orElse: () => SampleRate.k441,
      ),
      smartPunctuation: map['smartPunctuation'] as bool? ?? true,
      sttPreset: sttPreset,
      sttApiKey: _readSttApiKey(map),
      sttBaseUrl: _readSttBaseUrl(map, sttPreset),
      sttModelId: _readSttModelId(map, sttPreset),
      proxyUrl: map['proxyUrl'] as String? ?? '',
      periodStrength: (map['periodStrength'] as num?)?.toDouble() ?? 0.8,
      commaStrength: (map['commaStrength'] as num?)?.toDouble() ?? 0.55,
      questionStrength: (map['questionStrength'] as num?)?.toDouble() ?? 0.65,
      exclamationStrength:
          (map['exclamationStrength'] as num?)?.toDouble() ?? 0.45,
      ellipsisStrength: (map['ellipsisStrength'] as num?)?.toDouble() ?? 0.25,
      syncPersonalLexicon: map['syncPersonalLexicon'] as bool? ?? true,
      syncSettings: map['syncSettings'] as bool? ?? true,
      syncInputHabits: map['syncInputHabits'] as bool? ?? true,
      skin: AppSkin.values.firstWhere(
        (value) => value.name == map['skin'],
        orElse: () => AppSkin.bamboo,
      ),
      lastSyncAt: switch (map['lastSyncAt']) {
        final String value when value.isNotEmpty => DateTime.tryParse(value),
        _ => null,
      },
      personalLexicon: _readLexiconEntries(map['personalLexicon']),
      aiEnabled: map['aiEnabled'] as bool? ?? true,
      aiProvider: AiProvider.values.firstWhere(
        (value) => value.name == map['aiProvider'],
        orElse: () => AiProvider.groq,
      ),
      aiBaseUrl: map['aiBaseUrl'] as String? ?? AiProvider.groq.defaultBaseUrl,
      aiApiKey: map['aiApiKey'] as String? ?? '',
      aiModel: map['aiModel'] as String? ?? AiProvider.groq.defaultModel,
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
      unawaited(ImePlatformBridge.syncSettings(migrated));
      return migrated;
    }

    final initialState = SettingsState.fromMap(box.toMap());
    unawaited(ImePlatformBridge.syncSettings(initialState));
    return initialState;
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

  void updateSttPreset(SttPreset preset) {
    _save(
      state.copyWith(
        sttPreset: preset,
        sttBaseUrl: preset.defaultBaseUrl.isNotEmpty
            ? preset.defaultBaseUrl
            : state.sttBaseUrl,
        sttModelId: preset.defaultModelId.isNotEmpty
            ? preset.defaultModelId
            : state.sttModelId,
      ),
    );
  }

  void updateSttApiKey(String value) {
    _save(state.copyWith(sttApiKey: value.trim()));
  }

  void updateSttBaseUrl(String value) {
    _save(state.copyWith(sttBaseUrl: value.trim()));
  }

  void updateSttModelId(String value) {
    _save(state.copyWith(sttModelId: value.trim()));
  }

  void updateProxyUrl(String value) {
    _save(state.copyWith(proxyUrl: value.trim()));
  }

  void updatePeriodStrength(double value) {
    _save(state.copyWith(periodStrength: value));
  }

  void updateCommaStrength(double value) {
    _save(state.copyWith(commaStrength: value));
  }

  void updateQuestionStrength(double value) {
    _save(state.copyWith(questionStrength: value));
  }

  void updateExclamationStrength(double value) {
    _save(state.copyWith(exclamationStrength: value));
  }

  void updateEllipsisStrength(double value) {
    _save(state.copyWith(ellipsisStrength: value));
  }

  void toggleSyncPersonalLexicon(bool value) {
    _save(state.copyWith(syncPersonalLexicon: value));
  }

  void toggleSyncSettings(bool value) {
    _save(state.copyWith(syncSettings: value));
  }

  void toggleSyncInputHabits(bool value) {
    _save(state.copyWith(syncInputHabits: value));
  }

  void updateSkin(AppSkin value) {
    _save(state.copyWith(skin: value));
  }

  void addPersonalLexiconEntry({
    required String spokenForm,
    required String writtenForm,
  }) {
    final normalizedSpoken = spokenForm.trim();
    final normalizedWritten = writtenForm.trim();
    if (normalizedSpoken.isEmpty || normalizedWritten.isEmpty) {
      return;
    }

    final next = [...state.personalLexicon];
    final index = next.indexWhere(
      (entry) =>
          entry.spokenForm.trim().toLowerCase() ==
          normalizedSpoken.toLowerCase(),
    );
    final entry = PersonalLexiconEntry(
      id: index == -1 ? const Uuid().v4() : next[index].id,
      spokenForm: normalizedSpoken,
      writtenForm: normalizedWritten,
      enabled: true,
    );

    if (index == -1) {
      next.insert(0, entry);
    } else {
      next[index] = entry;
    }

    _save(state.copyWith(personalLexicon: next));
  }

  void updatePersonalLexiconEntry(PersonalLexiconEntry nextEntry) {
    final normalizedSpoken = nextEntry.spokenForm.trim();
    final normalizedWritten = nextEntry.writtenForm.trim();
    if (normalizedSpoken.isEmpty || normalizedWritten.isEmpty) {
      return;
    }

    final next = state.personalLexicon
        .map(
          (entry) => entry.id == nextEntry.id
              ? nextEntry.copyWith(
                  spokenForm: normalizedSpoken,
                  writtenForm: normalizedWritten,
                )
              : entry,
        )
        .toList();
    _save(state.copyWith(personalLexicon: next));
  }

  void togglePersonalLexiconEntry(String id, bool enabled) {
    final next = state.personalLexicon
        .map(
          (entry) => entry.id == id ? entry.copyWith(enabled: enabled) : entry,
        )
        .toList();
    _save(state.copyWith(personalLexicon: next));
  }

  void deletePersonalLexiconEntry(String id) {
    _save(
      state.copyWith(
        personalLexicon: state.personalLexicon
            .where((entry) => entry.id != id)
            .toList(),
      ),
    );
  }

  void markSyncedNow() {
    _save(state.copyWith(lastSyncAt: DateTime.now()));
  }

  void resetPunctuationTuning() {
    _save(
      state.copyWith(
        smartPunctuation: true,
        periodStrength: 0.8,
        commaStrength: 0.55,
        questionStrength: 0.65,
        exclamationStrength: 0.45,
        ellipsisStrength: 0.25,
      ),
    );
  }

  void toggleAiEnabled(bool value) {
    _save(state.copyWith(aiEnabled: value));
  }

  void updateAiProvider(AiProvider provider) {
    if (provider == AiProvider.custom) {
      _save(state.copyWith(aiProvider: provider));
      return;
    }
    _save(
      state.copyWith(
        aiProvider: provider,
        aiBaseUrl: provider.defaultBaseUrl,
        aiModel: provider.defaultModel,
      ),
    );
  }

  void updateAiBaseUrl(String value) {
    _save(state.copyWith(aiBaseUrl: value.trim()));
  }

  void updateAiApiKey(String value) {
    _save(state.copyWith(aiApiKey: value.trim()));
  }

  void updateAiModel(String value) {
    _save(state.copyWith(aiModel: value.trim()));
  }

  void _save(SettingsState next) {
    state = next;
    _persistFields(next);
    unawaited(ImePlatformBridge.syncSettings(next));
  }

  void _persistFields(SettingsState next) {
    final box = ref.read(settingsBoxProvider);
    box.put('provider', next.provider.name);
    box.put('languageCode', next.languageCode);
    box.put('sampleRate', next.sampleRate.name);
    box.put('smartPunctuation', next.smartPunctuation);
    box.put('sttPreset', next.sttPreset.name);
    box.put('sttApiKey', next.sttApiKey);
    box.put('sttBaseUrl', next.sttBaseUrl);
    box.put('sttModelId', next.sttModelId);
    box.delete('groqApiKey');
    box.delete('groqModel');
    box.put('proxyUrl', next.proxyUrl);
    box.put('periodStrength', next.periodStrength);
    box.put('commaStrength', next.commaStrength);
    box.put('questionStrength', next.questionStrength);
    box.put('exclamationStrength', next.exclamationStrength);
    box.put('ellipsisStrength', next.ellipsisStrength);
    box.put('syncPersonalLexicon', next.syncPersonalLexicon);
    box.put('syncSettings', next.syncSettings);
    box.put('syncInputHabits', next.syncInputHabits);
    box.put('skin', next.skin.name);
    box.put('lastSyncAt', next.lastSyncAt?.toIso8601String());
    box.put(
      'personalLexicon',
      next.personalLexicon.map((entry) => entry.toMap()).toList(),
    );
    box.put('aiEnabled', next.aiEnabled);
    box.put('aiProvider', next.aiProvider.name);
    box.put('aiBaseUrl', next.aiBaseUrl);
    box.put('aiApiKey', next.aiApiKey);
    box.put('aiModel', next.aiModel);
  }
}

SttPreset _readSttPreset(Map<dynamic, dynamic> map) {
  final stored = map['sttPreset'] as String?;
  if (stored != null) {
    return SttPreset.values.firstWhere(
      (value) => value.name == stored,
      orElse: () => SttPreset.groq,
    );
  }

  if ((map['groqApiKey'] as String?)?.isNotEmpty ?? false) {
    return SttPreset.groq;
  }

  if (_legacyGroqModelId(map['groqModel']) != null) {
    return SttPreset.groq;
  }

  return SttPreset.groq;
}

String _readSttApiKey(Map<dynamic, dynamic> map) {
  return ((map['sttApiKey'] as String?) ?? (map['groqApiKey'] as String?) ?? '')
      .trim();
}

String _readSttBaseUrl(Map<dynamic, dynamic> map, SttPreset preset) {
  final explicit = (map['sttBaseUrl'] as String?)?.trim() ?? '';
  if (explicit.isNotEmpty) {
    return explicit;
  }
  return preset.defaultBaseUrl;
}

String _readSttModelId(Map<dynamic, dynamic> map, SttPreset preset) {
  final explicit = (map['sttModelId'] as String?)?.trim() ?? '';
  if (explicit.isNotEmpty) {
    return explicit;
  }

  final legacy = _legacyGroqModelId(map['groqModel']);
  if (legacy != null) {
    return legacy;
  }

  return preset.defaultModelId;
}

String? _legacyGroqModelId(Object? raw) {
  if (raw is! String) {
    return null;
  }

  return switch (raw) {
    'largeV3' || 'whisper-large-v3' => 'whisper-large-v3',
    'largeV3Turbo' || 'whisper-large-v3-turbo' => 'whisper-large-v3-turbo',
    _ => null,
  };
}

List<PersonalLexiconEntry> _readLexiconEntries(Object? raw) {
  if (raw is! List) {
    return const [];
  }

  return raw.whereType<Map>().map(PersonalLexiconEntry.fromMap).toList();
}

const languageOptions = <String, String>{
  'zh-CN': '普通话',
  'en-US': '英语',
  'ja-JP': '日语',
  'fr-FR': '法语',
  'es-ES': '西班牙语',
  'de-DE': '德语',
};
