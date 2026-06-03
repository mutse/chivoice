import '../../features/recording/draft_rewrite.dart';

enum AiRewriteKind {
  cleanFillers,
  formal,
  concise,
  paragraph,
  todo,
  translate,
  summarize,
  custom,
}

class PromptTemplates {
  const PromptTemplates._();

  static String forAction({
    required AiRewriteKind kind,
    required String languageCode,
    String? targetLanguage,
    String? customInstruction,
  }) {
    final usesCjk = _usesCjk(languageCode);
    return switch (kind) {
      AiRewriteKind.cleanFillers => usesCjk
          ? '你是中文文本编辑助手。删除「嗯」「啊」「呃」「那个」「就是」「然后」「其实」等口语赘词和无意义重复，'
                '保持原句意与语气；不要改写句意，不要新增内容。只输出整理后的文本，不要任何解释。'
          : 'Remove filler words (um, uh, you know, like, actually) and unnecessary '
                'repetitions from the user message. Preserve meaning and tone. '
                'Output only the cleaned text, no commentary.',
      AiRewriteKind.formal => usesCjk
          ? '把口语化的中文文本改写为正式书面表达。保留原意和关键信息；使用礼貌用语（请/烦请/敬请等）；'
                '长度不超过原文 1.3 倍。只输出改写后的文本，不要解释。'
          : 'Rewrite the user message into formal written English. Preserve meaning, '
                'use polite phrasing ("could you please…", "kindly…"), keep length '
                'within 1.3x. Output only the rewritten text.',
      AiRewriteKind.concise => usesCjk
          ? '把用户的文本压缩为一句话，保留核心信息，去掉装饰性词语和重复表达。'
                '只输出压缩后的句子，不要解释。'
          : 'Compress the user message into a single sentence, preserving only the '
                'core information. Output only the compressed sentence.',
      AiRewriteKind.paragraph => usesCjk
          ? '把用户的长段文本按主题分段，每段 2–4 句话，段落之间空一行。'
                '不要新增信息，不要改写原意。只输出分段后的文本。'
          : 'Break the user message into paragraphs grouped by topic. Each paragraph '
                'should have 2–4 sentences, separated by blank lines. Do not add new '
                'information. Output only the segmented text.',
      AiRewriteKind.todo => usesCjk
          ? '从用户的文本中提取所有可执行的行动项，输出为 markdown 列表，每条以动词开头，'
                '简洁不超过 20 字。如果没有明确的行动项，从文本中合理推断 1–3 条。'
                '只输出列表，不要标题或解释。'
          : 'Extract all actionable items from the user message as a markdown bullet '
                'list. Each item should start with a verb and be concise. Output only '
                'the list.',
      AiRewriteKind.translate => _translatePrompt(targetLanguage ?? 'en'),
      AiRewriteKind.summarize => usesCjk
          ? '用 1–3 句话总结用户文本的要点，保留关键信息和数字。只输出总结。'
          : 'Summarize the user message in 1–3 sentences, preserving key facts and '
                'numbers. Output only the summary.',
      AiRewriteKind.custom => customInstruction?.trim().isNotEmpty == true
          ? '${customInstruction!.trim()}\n\n严格按照上述要求处理用户文本，只输出处理后的结果，不要解释。'
          : (usesCjk
                ? '请帮我整理下面这段文本，让它更适合发送。只输出整理后的文本，不要解释。'
                : 'Please clean up the following text so it is ready to send. '
                      'Output only the cleaned text.'),
    };
  }

  static String _translatePrompt(String target) {
    final targetLabel = _targetLanguageLabel(target);
    return 'Translate the user message into $targetLabel. '
        'Preserve tone and intent. Output only the translation, no commentary, '
        'no quotation marks around the result.';
  }

  static String _targetLanguageLabel(String code) {
    return switch (code) {
      'zh' || 'zh-CN' => '简体中文 (Simplified Chinese)',
      'zh-TW' => '繁体中文 (Traditional Chinese)',
      'en' || 'en-US' => 'English',
      'ja' || 'ja-JP' => '日本語 (Japanese)',
      'fr' || 'fr-FR' => 'Français (French)',
      'es' || 'es-ES' => 'Español (Spanish)',
      'de' || 'de-DE' => 'Deutsch (German)',
      _ => code,
    };
  }

  static bool _usesCjk(String languageCode) {
    return languageCode.startsWith('zh') || languageCode.startsWith('ja');
  }
}

AiRewriteKind kindFromDraftAction(DraftRewriteAction action) {
  return switch (action) {
    DraftRewriteAction.cleanFillers => AiRewriteKind.cleanFillers,
    DraftRewriteAction.formal => AiRewriteKind.formal,
    DraftRewriteAction.concise => AiRewriteKind.concise,
    DraftRewriteAction.paragraph => AiRewriteKind.paragraph,
    DraftRewriteAction.todo => AiRewriteKind.todo,
  };
}
