import 'prompt_templates.dart';

class ParsedInstruction {
  const ParsedInstruction({
    required this.kind,
    required this.payload,
    this.targetLanguage,
    this.customInstruction,
  });

  final AiRewriteKind? kind;
  final String payload;
  final String? targetLanguage;
  final String? customInstruction;

  bool get hasInstruction => kind != null;
}

class InstructionParser {
  const InstructionParser._();

  static ParsedInstruction parse(String text, {required String languageCode}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return ParsedInstruction(kind: null, payload: trimmed);
    }

    final translation = _matchTranslate(trimmed);
    if (translation != null) {
      return translation;
    }

    for (final entry in _zhPrefixes.entries) {
      final match = entry.key.firstMatch(trimmed);
      if (match != null) {
        return ParsedInstruction(
          kind: entry.value,
          payload: trimmed.substring(match.end).trim(),
        );
      }
    }

    for (final entry in _enPrefixes.entries) {
      final match = entry.key.firstMatch(trimmed);
      if (match != null) {
        return ParsedInstruction(
          kind: entry.value,
          payload: trimmed.substring(match.end).trim(),
        );
      }
    }

    return ParsedInstruction(kind: null, payload: trimmed);
  }

  static final RegExp _translatePrefix = RegExp(
    r'^(翻译成|翻成|译成|translate\s+to|translate\s+into)\s*'
    r'(简体中文|繁体中文|中文|chinese|英文|英语|english|日文|日语|japanese|'
    r'法文|法语|french|西班牙文|西班牙语|spanish|德文|德语|german)'
    r'[,，:：\s]+',
    caseSensitive: false,
  );

  static ParsedInstruction? _matchTranslate(String text) {
    final match = _translatePrefix.firstMatch(text);
    if (match == null) {
      return null;
    }
    final targetRaw = (match.group(2) ?? '').toLowerCase();
    final target = _languageNameToCode(targetRaw);
    return ParsedInstruction(
      kind: AiRewriteKind.translate,
      payload: text.substring(match.end).trim(),
      targetLanguage: target,
    );
  }

  static String _languageNameToCode(String name) {
    if (name.contains('英') || name.contains('english')) return 'en';
    if (name.contains('繁体')) return 'zh-TW';
    if (name.contains('中') || name.contains('chinese')) return 'zh-CN';
    if (name.contains('日') || name.contains('japanese')) return 'ja';
    if (name.contains('法') || name.contains('french')) return 'fr';
    if (name.contains('西班牙') || name.contains('spanish')) return 'es';
    if (name.contains('德') || name.contains('german')) return 'de';
    return name;
  }

  static final Map<RegExp, AiRewriteKind> _zhPrefixes = {
    RegExp(r'^(总结|概括|归纳)(一下|下)?[,，:：\s]*'): AiRewriteKind.summarize,
    RegExp(r'^(改写|润色|整理|优化)(一下|下)?[,，:：\s]*'): AiRewriteKind.formal,
    RegExp(r'^(压缩|精简|简化)(一下|下)?[,，:：\s]*'): AiRewriteKind.concise,
    RegExp(r'^(分段|断句)(一下|下)?[,，:：\s]*'): AiRewriteKind.paragraph,
    RegExp(r'^(列待办|提炼待办|罗列待办|todo)[,，:：\s]*', caseSensitive: false):
        AiRewriteKind.todo,
    RegExp(r'^(去口语|去赘词|清理)(一下|下)?[,，:：\s]*'): AiRewriteKind.cleanFillers,
  };

  static final Map<RegExp, AiRewriteKind> _enPrefixes = {
    RegExp(r'^(summarize|summary)[,:\s]+', caseSensitive: false):
        AiRewriteKind.summarize,
    RegExp(r'^(rewrite|polish|formalize)[,:\s]+', caseSensitive: false):
        AiRewriteKind.formal,
    RegExp(r'^(shorten|condense|tldr)[,:\s]+', caseSensitive: false):
        AiRewriteKind.concise,
    RegExp(r'^(paragraph|split)[,:\s]+', caseSensitive: false):
        AiRewriteKind.paragraph,
    RegExp(r'^(todo|action\s+items?)[,:\s]+', caseSensitive: false):
        AiRewriteKind.todo,
    RegExp(r'^(clean\s+fillers?|remove\s+fillers?)[,:\s]+', caseSensitive: false):
        AiRewriteKind.cleanFillers,
  };
}
