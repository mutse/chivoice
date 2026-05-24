import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/recording/draft_rewrite.dart';
import '../../features/settings/settings_provider.dart';
import '../api_proxy.dart';
import 'openai_compatible_client.dart';
import 'prompt_templates.dart';

class AiRewriteRequest {
  const AiRewriteRequest({
    required this.text,
    required this.kind,
    required this.languageCode,
    this.targetLanguage,
    this.customInstruction,
    this.temperature = 0.3,
  });

  final String text;
  final AiRewriteKind kind;
  final String languageCode;
  final String? targetLanguage;
  final String? customInstruction;
  final double temperature;
}

class AiRewriteResult {
  const AiRewriteResult({
    required this.text,
    required this.usedOfflineFallback,
    this.fallbackReason,
  });

  final String text;
  final bool usedOfflineFallback;
  final String? fallbackReason;
}

class AiRewriteService {
  AiRewriteService({required this.settingsRef});

  final Ref settingsRef;

  bool get isConfigured {
    final settings = settingsRef.read(settingsProvider);
    return settings.aiEnabled && settings.aiApiKey.trim().isNotEmpty;
  }

  Future<AiRewriteResult> rewrite(AiRewriteRequest request) async {
    final settings = settingsRef.read(settingsProvider);
    final canCall = settings.aiEnabled && settings.aiApiKey.trim().isNotEmpty;

    if (!canCall) {
      final fallback = _offlineFallback(request);
      return AiRewriteResult(
        text: fallback,
        usedOfflineFallback: true,
        fallbackReason: settings.aiEnabled
            ? '未配置 AI API Key，已使用本地整理。'
            : 'AI 增强已关闭，已使用本地整理。',
      );
    }

    final client = _buildClient(settings);
    try {
      final text = await client.complete(
        systemPrompt: PromptTemplates.forAction(
          kind: request.kind,
          languageCode: request.languageCode,
          targetLanguage: request.targetLanguage,
          customInstruction: request.customInstruction,
        ),
        userText: request.text,
        temperature: request.temperature,
      );
      return AiRewriteResult(text: text, usedOfflineFallback: false);
    } on AiRemoteException catch (error) {
      final fallback = _offlineFallback(request);
      return AiRewriteResult(
        text: fallback,
        usedOfflineFallback: true,
        fallbackReason: 'AI 失败：${error.message} · 已使用本地整理。',
      );
    } catch (error) {
      final fallback = _offlineFallback(request);
      return AiRewriteResult(
        text: fallback,
        usedOfflineFallback: true,
        fallbackReason: 'AI 异常：$error · 已使用本地整理。',
      );
    }
  }

  Stream<String> stream(AiRewriteRequest request) async* {
    final settings = settingsRef.read(settingsProvider);
    final canCall = settings.aiEnabled && settings.aiApiKey.trim().isNotEmpty;
    if (!canCall) {
      yield _offlineFallback(request);
      return;
    }

    final client = _buildClient(settings);
    try {
      yield* client.completeStream(
        systemPrompt: PromptTemplates.forAction(
          kind: request.kind,
          languageCode: request.languageCode,
          targetLanguage: request.targetLanguage,
          customInstruction: request.customInstruction,
        ),
        userText: request.text,
        temperature: request.temperature,
      );
    } on AiRemoteException {
      yield _offlineFallback(request);
    }
  }

  OpenAiCompatibleClient _buildClient(SettingsState settings) {
    final apiProxy = ApiProxy(
      baseUrl: settings.aiBaseUrl.isEmpty
          ? settings.aiProvider.defaultBaseUrl
          : settings.aiBaseUrl,
      headers: {'Authorization': 'Bearer ${settings.aiApiKey.trim()}'},
    );
    return OpenAiCompatibleClient(
      apiProxy: apiProxy,
      model: settings.aiModel.isEmpty
          ? settings.aiProvider.defaultModel
          : settings.aiModel,
    );
  }

  String _offlineFallback(AiRewriteRequest request) {
    final draftAction = switch (request.kind) {
      AiRewriteKind.cleanFillers => DraftRewriteAction.cleanFillers,
      AiRewriteKind.formal => DraftRewriteAction.formal,
      AiRewriteKind.concise => DraftRewriteAction.concise,
      AiRewriteKind.paragraph => DraftRewriteAction.paragraph,
      AiRewriteKind.todo => DraftRewriteAction.todo,
      AiRewriteKind.translate => null,
      AiRewriteKind.summarize => DraftRewriteAction.concise,
      AiRewriteKind.custom => DraftRewriteAction.cleanFillers,
    };
    if (draftAction == null) {
      return request.text;
    }
    return rewriteDraft(
      request.text,
      action: draftAction,
      languageCode: request.languageCode,
    );
  }
}

final aiRewriteServiceProvider = Provider<AiRewriteService>((ref) {
  return AiRewriteService(settingsRef: ref);
});
