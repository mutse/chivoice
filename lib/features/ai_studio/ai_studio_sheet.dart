import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/ai/ai_rewrite_service.dart';
import '../../services/ai/instruction_parser.dart';
import '../../services/ai/prompt_templates.dart';
import '../settings/settings_provider.dart';
import '../shared/theme.dart';

class _ActionDescriptor {
  const _ActionDescriptor({
    required this.kind,
    required this.label,
    required this.icon,
    required this.description,
    this.requiresTarget = false,
  });

  final AiRewriteKind kind;
  final String label;
  final IconData icon;
  final String description;
  final bool requiresTarget;
}

const _actions = <_ActionDescriptor>[
  _ActionDescriptor(
    kind: AiRewriteKind.cleanFillers,
    label: '去口语',
    icon: Icons.cleaning_services_outlined,
    description: '删掉嗯啊然后等赘词',
  ),
  _ActionDescriptor(
    kind: AiRewriteKind.formal,
    label: '更正式',
    icon: Icons.draw_outlined,
    description: '改写为书面表达',
  ),
  _ActionDescriptor(
    kind: AiRewriteKind.concise,
    label: '压缩',
    icon: Icons.short_text,
    description: '提炼成一句话',
  ),
  _ActionDescriptor(
    kind: AiRewriteKind.paragraph,
    label: '分段',
    icon: Icons.segment_outlined,
    description: '按主题断段',
  ),
  _ActionDescriptor(
    kind: AiRewriteKind.todo,
    label: '提炼待办',
    icon: Icons.checklist_rtl_outlined,
    description: '列出行动项',
  ),
  _ActionDescriptor(
    kind: AiRewriteKind.translate,
    label: '翻译',
    icon: Icons.translate,
    description: '换一种语言',
    requiresTarget: true,
  ),
  _ActionDescriptor(
    kind: AiRewriteKind.summarize,
    label: '总结',
    icon: Icons.summarize_outlined,
    description: '抓取核心要点',
  ),
  _ActionDescriptor(
    kind: AiRewriteKind.custom,
    label: '指令…',
    icon: Icons.tune,
    description: '自定义提示词',
  ),
];

const _translateTargets = <String, String>{
  'en': '英文',
  'zh-CN': '中文',
  'ja': '日文',
  'fr': '法文',
  'es': '西班牙文',
  'de': '德文',
};

Future<String?> showAiStudioSheet(
  BuildContext context, {
  required String originalText,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _AiStudioSheet(originalText: originalText),
  );
}

class _AiStudioSheet extends ConsumerStatefulWidget {
  const _AiStudioSheet({required this.originalText});

  final String originalText;

  @override
  ConsumerState<_AiStudioSheet> createState() => _AiStudioSheetState();
}

class _AiStudioSheetState extends ConsumerState<_AiStudioSheet> {
  AiRewriteKind? _activeKind;
  String? _translateTarget;
  String _customInstruction = '';
  String _output = '';
  bool _running = false;
  bool _usedOfflineFallback = false;
  String? _fallbackReason;
  ParsedInstruction? _autoDetected;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    final detected = InstructionParser.parse(
      widget.originalText,
      languageCode: settings.languageCode,
    );
    if (detected.hasInstruction) {
      _autoDetected = detected;
      _activeKind = detected.kind;
      _translateTarget = detected.targetLanguage;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final mediaQuery = MediaQuery.of(context);
    final isAiOn = settings.aiEnabled && settings.aiApiKey.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: mediaQuery.size.height * 0.9,
          ),
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kPanel,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: kPaperLine),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: kPaperLine,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                _Header(isOnline: isAiOn, autoDetected: _autoDetected),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '原文',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        _OriginalCard(text: widget.originalText),
                        const SizedBox(height: 18),
                        Text(
                          '风格',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        _ActionGrid(
                          activeKind: _activeKind,
                          onPick: _onPickAction,
                        ),
                        if (_activeKind == AiRewriteKind.translate) ...[
                          const SizedBox(height: 14),
                          _TranslateTargets(
                            selected: _translateTarget,
                            onPick: (value) =>
                                setState(() => _translateTarget = value),
                          ),
                        ],
                        if (_activeKind == AiRewriteKind.custom) ...[
                          const SizedBox(height: 14),
                          TextField(
                            decoration: const InputDecoration(
                              labelText: '自定义指令',
                              hintText: '比如：改成更友好的邮件结尾',
                            ),
                            minLines: 2,
                            maxLines: 4,
                            onChanged: (value) =>
                                setState(() => _customInstruction = value),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Text(
                              'AI 输出',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const Spacer(),
                            if (_output.isNotEmpty && !_running)
                              TextButton.icon(
                                onPressed: () => _runRewrite(temperature: 0.7),
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('重生成'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _OutputCard(
                          text: _output,
                          isRunning: _running,
                          usedOffline: _usedOfflineFallback,
                          fallbackReason: _fallbackReason,
                        ),
                      ],
                    ),
                  ),
                ),
                _BottomBar(
                  canApply: _output.trim().isNotEmpty && !_running,
                  onCancel: () => Navigator.of(context).pop(),
                  onApply: () => Navigator.of(context).pop(_output.trim()),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onPickAction(AiRewriteKind kind) {
    setState(() {
      _activeKind = kind;
      if (kind == AiRewriteKind.translate) {
        _translateTarget ??= 'en';
      }
    });
    if (kind != AiRewriteKind.custom && kind != AiRewriteKind.translate) {
      _runRewrite();
    } else if (kind == AiRewriteKind.translate &&
        _translateTarget != null) {
      _runRewrite();
    }
  }

  Future<void> _runRewrite({double temperature = 0.3}) async {
    final kind = _activeKind;
    if (kind == null) {
      return;
    }
    if (kind == AiRewriteKind.custom && _customInstruction.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先填写自定义指令')),
      );
      return;
    }
    if (kind == AiRewriteKind.translate && _translateTarget == null) {
      return;
    }

    setState(() {
      _running = true;
      _output = '';
      _usedOfflineFallback = false;
      _fallbackReason = null;
    });

    final settings = ref.read(settingsProvider);
    final service = ref.read(aiRewriteServiceProvider);
    final payload = _autoDetected?.payload.isNotEmpty == true
        ? _autoDetected!.payload
        : widget.originalText;

    final result = await service.rewrite(
      AiRewriteRequest(
        text: payload,
        kind: kind,
        languageCode: settings.languageCode,
        targetLanguage: _translateTarget,
        customInstruction:
            kind == AiRewriteKind.custom ? _customInstruction : null,
        temperature: temperature,
      ),
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _output = result.text;
      _running = false;
      _usedOfflineFallback = result.usedOfflineFallback;
      _fallbackReason = result.fallbackReason;
    });
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isOnline, required this.autoDetected});

  final bool isOnline;
  final ParsedInstruction? autoDetected;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 12, 14),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: primary, size: 22),
          const SizedBox(width: 10),
          Text(
            'AI 整理',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(width: 10),
          if (autoDetected?.hasInstruction == true)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: primary.withValues(alpha: 0.32)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_fix_high, size: 14, color: primary),
                  const SizedBox(width: 4),
                  Text(
                    '已识别指令',
                    style: TextStyle(
                      fontSize: 12,
                      color: primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else if (!isOnline)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.5),
                ),
              ),
              child: const Text(
                '离线模式',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFFCB6F1A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            tooltip: '关闭',
          ),
        ],
      ),
    );
  }
}

class _OriginalCard extends StatelessWidget {
  const _OriginalCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kPaperLine),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyLarge,
        maxLines: 6,
        overflow: TextOverflow.fade,
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.activeKind, required this.onPick});

  final AiRewriteKind? activeKind;
  final ValueChanged<AiRewriteKind> onPick;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.92,
      children: _actions.map((action) {
        final isActive = action.kind == activeKind;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => onPick(action.kind),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isActive
                    ? primary.withValues(alpha: 0.14)
                    : Colors.white.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isActive
                      ? primary
                      : kPaperLine,
                  width: isActive ? 1.4 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(action.icon, color: primary, size: 22),
                  const SizedBox(height: 6),
                  Text(
                    action.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TranslateTargets extends StatelessWidget {
  const _TranslateTargets({required this.selected, required this.onPick});

  final String? selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _translateTargets.entries.map((entry) {
        final isActive = entry.key == selected;
        return ChoiceChip(
          label: Text(entry.value),
          selected: isActive,
          onSelected: (_) => onPick(entry.key),
          selectedColor: primary.withValues(alpha: 0.18),
          side: BorderSide(
            color: isActive ? primary : kPaperLine,
          ),
        );
      }).toList(),
    );
  }
}

class _OutputCard extends StatelessWidget {
  const _OutputCard({
    required this.text,
    required this.isRunning,
    required this.usedOffline,
    required this.fallbackReason,
  });

  final String text;
  final bool isRunning;
  final bool usedOffline;
  final String? fallbackReason;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: usedOffline ? Colors.orange.withValues(alpha: 0.4) : kPaperLine,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isRunning)
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: primary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '整理中…',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            )
          else if (text.isEmpty)
            Text(
              '选择上方风格后，结果会显示在这里。',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            SelectableText(
              text,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          if (fallbackReason != null) ...[
            const SizedBox(height: 8),
            Text(
              fallbackReason!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFFCB6F1A),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.canApply,
    required this.onCancel,
    required this.onApply,
  });

  final bool canApply;
  final VoidCallback onCancel;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onCancel,
              child: const Text('取消'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: canApply ? onApply : null,
              icon: const Icon(Icons.check),
              label: const Text('替换原文'),
            ),
          ),
        ],
      ),
    );
  }
}
