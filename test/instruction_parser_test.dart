import 'package:chivoice/services/ai/instruction_parser.dart';
import 'package:chivoice/services/ai/prompt_templates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InstructionParser', () {
    test('detects 翻译成英文 prefix and strips it', () {
      final parsed = InstructionParser.parse(
        '翻译成英文 你好世界',
        languageCode: 'zh-CN',
      );
      expect(parsed.hasInstruction, isTrue);
      expect(parsed.kind, AiRewriteKind.translate);
      expect(parsed.targetLanguage, 'en');
      expect(parsed.payload, '你好世界');
    });

    test('detects 总结 prefix', () {
      final parsed = InstructionParser.parse(
        '总结一下，今天会议讨论了三件事',
        languageCode: 'zh-CN',
      );
      expect(parsed.kind, AiRewriteKind.summarize);
      expect(parsed.payload, '今天会议讨论了三件事');
    });

    test('detects 改写 prefix as formal', () {
      final parsed = InstructionParser.parse(
        '改写一下 我想问下明天会议是否照常',
        languageCode: 'zh-CN',
      );
      expect(parsed.kind, AiRewriteKind.formal);
      expect(parsed.payload, '我想问下明天会议是否照常');
    });

    test('detects english translate to chinese', () {
      final parsed = InstructionParser.parse(
        'Translate to Chinese: hello world',
        languageCode: 'en-US',
      );
      expect(parsed.kind, AiRewriteKind.translate);
      expect(parsed.targetLanguage, 'zh-CN');
      expect(parsed.payload, 'hello world');
    });

    test('returns hasInstruction false when no prefix matches', () {
      final parsed = InstructionParser.parse(
        '今天天气真不错',
        languageCode: 'zh-CN',
      );
      expect(parsed.hasInstruction, isFalse);
      expect(parsed.payload, '今天天气真不错');
    });

    test('handles empty text', () {
      final parsed = InstructionParser.parse('   ', languageCode: 'zh-CN');
      expect(parsed.hasInstruction, isFalse);
      expect(parsed.payload, '');
    });

    test('translate prefix without target falls through to payload', () {
      final parsed = InstructionParser.parse(
        '翻译这段话',
        languageCode: 'zh-CN',
      );
      expect(parsed.hasInstruction, isFalse);
    });
  });

  group('PromptTemplates', () {
    test('cleanFillers prompt mentions filler removal for zh', () {
      final prompt = PromptTemplates.forAction(
        kind: AiRewriteKind.cleanFillers,
        languageCode: 'zh-CN',
      );
      expect(prompt, contains('赘词'));
    });

    test('translate prompt encodes target language', () {
      final prompt = PromptTemplates.forAction(
        kind: AiRewriteKind.translate,
        languageCode: 'zh-CN',
        targetLanguage: 'en',
      );
      expect(prompt, contains('English'));
    });

    test('custom prompt embeds user instruction', () {
      final prompt = PromptTemplates.forAction(
        kind: AiRewriteKind.custom,
        languageCode: 'zh-CN',
        customInstruction: '改成婉拒邮件',
      );
      expect(prompt, contains('改成婉拒邮件'));
    });

    test('custom prompt without instruction has zh fallback', () {
      final prompt = PromptTemplates.forAction(
        kind: AiRewriteKind.custom,
        languageCode: 'zh-CN',
      );
      expect(prompt, contains('整理'));
    });
  });
}
