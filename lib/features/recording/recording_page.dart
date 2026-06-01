import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/ai/instruction_parser.dart';
import '../../services/ai/prompt_templates.dart';
import '../ai_studio/ai_studio_sheet.dart';
import '../settings/settings_provider.dart';
import '../shared/theme.dart';
import '../shared/widgets/ink_wash_background.dart';
import '../transcript/export_service.dart';
import '../transcript/export_sheet.dart';
import '../transcript/transcript_provider.dart';
import 'audio_recorder_service.dart';
import 'draft_rewrite.dart';
import 'mic_button.dart';
import 'recording_provider.dart';
import 'waveform_widget.dart';

class RecordingPage extends ConsumerStatefulWidget {
  const RecordingPage({super.key});

  @override
  ConsumerState<RecordingPage> createState() => _RecordingPageState();
}

class _RecordingPageState extends ConsumerState<RecordingPage> {
  late final TextEditingController _controller = TextEditingController();
  late final FocusNode _draftFocusNode = FocusNode();
  String? _lastRewriteSnapshot;

  @override
  void dispose() {
    _controller.dispose();
    _draftFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recording = ref.watch(recordingProvider);
    final settings = ref.watch(settingsProvider);
    final recorder = ref.watch(audioRecorderServiceProvider);
    final transcript = recording.transcriptId == null
        ? null
        : ref.watch(transcriptByIdProvider(recording.transcriptId!));

    ref.listen<RecordingState>(recordingProvider, (previous, next) {
      final message = next.errorMessage;
      if (message != null && message.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            action: SnackBarAction(
              label: '关闭',
              onPressed: () =>
                  ref.read(recordingProvider.notifier).clearMessage(),
            ),
          ),
        );
      }

      if (_controller.text != next.liveText) {
        _controller.value = TextEditingValue(
          text: next.liveText,
          selection: TextSelection.collapsed(offset: next.liveText.length),
        );
      }
    });

    final hasDraft = recording.liveText.trim().isNotEmpty;
    final detectedInstruction = hasDraft
        ? InstructionParser.parse(
            recording.liveText,
            languageCode: settings.languageCode,
          )
        : null;
    final aiReady = settings.aiEnabled && settings.aiApiKey.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(switch (recording.status) {
          RecordingStatus.recording => '倾听中',
          RecordingStatus.processing => '整理语音中',
          _ when hasDraft => '语音输入结果',
          _ => '语音输入法',
        }),
        actions: [
          IconButton(
            onPressed: () => context.go('/history'),
            icon: const Icon(Icons.auto_stories_outlined),
            tooltip: '稿库',
          ),
          if (hasDraft)
            IconButton(
              onPressed: () =>
                  ref.read(recordingProvider.notifier).deleteCurrentDraft(),
              icon: const Icon(Icons.delete_outline),
              tooltip: '丢弃本稿',
            ),
          IconButton(
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
          ),
        ],
      ),
      body: InkWashBackground(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 130),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: switch (recording.status) {
                      RecordingStatus.recording => _ListeningState(
                        key: const ValueKey('listening'),
                        recorder: recorder,
                        partialText: recording.liveText,
                        elapsedSeconds: recording.elapsedSeconds,
                        languageLabel:
                            languageOptions[settings.languageCode] ??
                            settings.languageCode,
                        onStop: () => ref
                            .read(recordingProvider.notifier)
                            .stopRecording(),
                      ),
                      RecordingStatus.processing => _ProcessingState(
                        key: const ValueKey('processing'),
                        partialText: recording.liveText,
                      ),
                      _ when hasDraft => _DraftState(
                        key: const ValueKey('draft'),
                        controller: _controller,
                        focusNode: _draftFocusNode,
                        title: _recordingTitle(transcript?.createdAt),
                        modelLabel: _sttModelLabel(settings),
                        languageLabel:
                            languageOptions[settings.languageCode] ??
                            settings.languageCode,
                        durationLabel: _formatDuration(
                          recording.elapsedSeconds,
                        ),
                        wordCount: recording.wordCount,
                        aiReady: aiReady,
                        detectedInstruction: detectedInstruction,
                        onChanged: (value) => ref
                            .read(recordingProvider.notifier)
                            .updateDraftText(value),
                        onCopy: _copyDraftText,
                        onFocusEditor: _focusDraftEditor,
                        onShare: () => _openExportSheet(
                          context,
                          settings: settings,
                          recording: recording,
                        ),
                        onRewrite: (action) =>
                            _applyDraftRewrite(action, settings.languageCode),
                        onAiStudio: () => _openAiStudio(context),
                        onOpenTranslationStudio: () => _openAiStudio(
                          context,
                          initialKind: AiRewriteKind.translate,
                        ),
                        onRunDetectedInstruction:
                            detectedInstruction != null &&
                                detectedInstruction.hasInstruction
                            ? () => _openAiStudio(
                                context,
                                initialKind: detectedInstruction.kind,
                                initialTargetLanguage:
                                    detectedInstruction.targetLanguage,
                                autoRunOnOpen: true,
                              )
                            : null,
                        onClear: () => ref
                            .read(recordingProvider.notifier)
                            .deleteCurrentDraft(),
                        onQuickPunctuation: _appendQuickPunctuation,
                        onQuickTranslate: _runQuickTranslation,
                      ),
                      _ => _IdleState(
                        key: const ValueKey('idle'),
                        languageLabel:
                            languageOptions[settings.languageCode] ??
                            settings.languageCode,
                        smartPunctuation: settings.smartPunctuation,
                        modelChips: _buildHomeChips(settings),
                        onStart: () => ref
                            .read(recordingProvider.notifier)
                            .startRecording(),
                        onOpenHistory: () => context.go('/history'),
                        onCycleLanguage: _cycleLanguage,
                        onOpenSettings: () => context.go('/settings'),
                      ),
                    },
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _ModeBar(
                settings: settings,
                isRecording: recording.status == RecordingStatus.recording,
                hasDraft: hasDraft,
              ),
              const SizedBox(height: 18),
              _FeatureShowcase(
                hasDraft: hasDraft,
                lexiconCount: settings.personalLexicon.length,
                onOpenLexicon: () => context.push('/settings/lexicon'),
                onOpenPunctuation: () => context.push('/settings/punctuation'),
                onOpenSync: () => context.push('/settings/sync'),
                onOpenSkins: () => context.push('/settings/skins'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAiStudio(
    BuildContext context, {
    AiRewriteKind? initialKind,
    String? initialTargetLanguage,
    bool autoRunOnOpen = false,
  }) async {
    final original = _controller.text.trim();
    if (original.isEmpty) {
      return;
    }
    final result = await showAiStudioSheet(
      context,
      originalText: original,
      initialKind: initialKind,
      initialTargetLanguage: initialTargetLanguage,
      autoRunOnOpen: autoRunOnOpen,
    );
    if (!mounted || result == null || result.isEmpty || result == original) {
      return;
    }
    _lastRewriteSnapshot = original;
    _controller.value = TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
    ref.read(recordingProvider.notifier).updateDraftText(result);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('已应用 AI 整理结果'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () {
            final snapshot = _lastRewriteSnapshot;
            if (snapshot == null) {
              return;
            }
            _controller.value = TextEditingValue(
              text: snapshot,
              selection: TextSelection.collapsed(offset: snapshot.length),
            );
            ref.read(recordingProvider.notifier).updateDraftText(snapshot);
            _lastRewriteSnapshot = null;
          },
        ),
      ),
    );
  }

  Future<void> _copyDraftText() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('文字已复制到剪贴板')));
  }

  void _focusDraftEditor() {
    _draftFocusNode.requestFocus();
  }

  void _cycleLanguage() {
    final current = ref.read(settingsProvider).languageCode;
    final keys = languageOptions.keys.toList(growable: false);
    final index = keys.indexOf(current);
    final next = keys[(index + 1) % keys.length];
    ref.read(settingsProvider.notifier).updateLanguage(next);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已切换为 ${languageOptions[next] ?? next}')),
    );
  }

  Future<void> _runQuickTranslation(String targetLanguage) {
    return _openAiStudio(
      context,
      initialKind: AiRewriteKind.translate,
      initialTargetLanguage: targetLanguage,
      autoRunOnOpen: true,
    );
  }

  void _appendQuickPunctuation(String symbol) {
    final next = '${_controller.text.trimRight()}$symbol';
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    ref.read(recordingProvider.notifier).updateDraftText(next);
  }

  void _applyDraftRewrite(DraftRewriteAction action, String languageCode) {
    final original = _controller.text.trim();
    if (original.isEmpty) {
      return;
    }

    final rewritten = rewriteDraft(
      original,
      action: action,
      languageCode: languageCode,
    );
    if (rewritten == original) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('这段内容已经比较利落了，可以直接发送。')));
      return;
    }

    _lastRewriteSnapshot = original;
    _controller.value = TextEditingValue(
      text: rewritten,
      selection: TextSelection.collapsed(offset: rewritten.length),
    );
    ref.read(recordingProvider.notifier).updateDraftText(rewritten);

    final option = draftRewriteOptions.firstWhere(
      (item) => item.action == action,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已应用${option.label}'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () {
            final snapshot = _lastRewriteSnapshot;
            if (snapshot == null) {
              return;
            }
            _controller.value = TextEditingValue(
              text: snapshot,
              selection: TextSelection.collapsed(offset: snapshot.length),
            );
            ref.read(recordingProvider.notifier).updateDraftText(snapshot);
            _lastRewriteSnapshot = null;
          },
        ),
      ),
    );
  }

  void _openExportSheet(
    BuildContext context, {
    required SettingsState settings,
    required RecordingState recording,
  }) {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }

    ref.read(recordingProvider.notifier).updateDraftText(text);
    final entry = TranscriptEntry(
      id: recording.transcriptId ?? 'live',
      text: text,
      createdAt: DateTime.now(),
      languageCode: settings.languageCode,
      wordCount: _estimateDraftLength(text),
    );
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ExportSheet(
        entry: entry,
        exportService: ref.read(exportServiceProvider),
      ),
    );
  }

  int _estimateDraftLength(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 0;
    }
    final hanCount = RegExp(r'[\u4E00-\u9FFF]').allMatches(trimmed).length;
    if (hanCount > 0 && !trimmed.contains(RegExp(r'\s'))) {
      return hanCount;
    }
    return trimmed.split(RegExp(r'\s+')).length;
  }
}

class _IdleState extends StatelessWidget {
  const _IdleState({
    super.key,
    required this.languageLabel,
    required this.smartPunctuation,
    required this.modelChips,
    required this.onStart,
    required this.onOpenHistory,
    required this.onCycleLanguage,
    required this.onOpenSettings,
  });

  final String languageLabel;
  final bool smartPunctuation;
  final List<_InfoPillData> modelChips;
  final VoidCallback onStart;
  final VoidCallback onOpenHistory;
  final VoidCallback onCycleLanguage;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('轻声落字，开口即写', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          '参考输入法式流程设计，点击麦克风开始说话，结果会自动整理成可发送的文字。',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        Text('当前模式', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _InfoPill(
              label: languageLabel,
              icon: Icons.language,
              highlighted: true,
            ),
            _InfoPill(
              label: smartPunctuation ? '标点自动' : '手动整理',
              icon: Icons.auto_awesome,
            ),
            ...modelChips.map(
              (item) => _InfoPill(
                label: item.label,
                icon: item.icon,
                highlighted: item.highlighted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const Center(child: _WaveformPlaceholder()),
        const SizedBox(height: 24),
        Center(child: MicButton(isRecording: false, onPressed: onStart)),
        const SizedBox(height: 16),
        Center(
          child: Text('点击开始录音', style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            '支持实时转写、AI 整理、快捷翻译与导出分享。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _CompactActionButton(
                icon: Icons.history,
                label: '稿库',
                onTap: onOpenHistory,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CompactActionButton(
                icon: Icons.swap_horiz,
                label: '切换语言',
                onTap: onCycleLanguage,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CompactActionButton(
                icon: Icons.tune,
                label: '设置',
                onTap: onOpenSettings,
                highlighted: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ListeningState extends StatelessWidget {
  const _ListeningState({
    super.key,
    required this.recorder,
    required this.partialText,
    required this.elapsedSeconds,
    required this.languageLabel,
    required this.onStop,
  });

  final AudioRecorderService recorder;
  final String partialText;
  final int elapsedSeconds;
  final String languageLabel;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPreview = partialText.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('倾听中…', style: theme.textTheme.headlineMedium),
            ),
            _MetricChip(icon: Icons.language, value: languageLabel),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kPaperLine),
          ),
          child: Text(
            hasPreview ? partialText : '正在把你的话落成文字…',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: hasPreview
                ? theme.textTheme.bodyLarge
                : theme.textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: WaveformWidget(
            amplitudeStream: recorder.amplitudeStream,
            activeColor: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        Center(child: MicButton(isRecording: true, onPressed: onStop)),
        const SizedBox(height: 16),
        Center(
          child: Text(
            _formatDuration(elapsedSeconds),
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            '再次点击即可停止录音，结果会自动进入预览。',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _ProcessingState extends StatelessWidget {
  const _ProcessingState({super.key, required this.partialText});

  final String partialText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final hasPreview = partialText.trim().isNotEmpty;

    return Column(
      children: [
        const SizedBox(height: 8),
        SizedBox(
          width: 56,
          height: 56,
          child: CircularProgressIndicator(strokeWidth: 3, color: primary),
        ),
        const SizedBox(height: 20),
        Text('整理语音中', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 10),
        Text(
          '正在合并实时转写与最终识别结果，并根据你的偏好补全标点。',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        if (hasPreview) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.68),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kPaperLine),
            ),
            child: Text(
              partialText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ],
      ],
    );
  }
}

class _DraftState extends StatelessWidget {
  const _DraftState({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.title,
    required this.modelLabel,
    required this.languageLabel,
    required this.durationLabel,
    required this.wordCount,
    required this.aiReady,
    required this.detectedInstruction,
    required this.onChanged,
    required this.onCopy,
    required this.onFocusEditor,
    required this.onShare,
    required this.onRewrite,
    required this.onAiStudio,
    required this.onOpenTranslationStudio,
    required this.onRunDetectedInstruction,
    required this.onClear,
    required this.onQuickPunctuation,
    required this.onQuickTranslate,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String title;
  final String modelLabel;
  final String languageLabel;
  final String durationLabel;
  final int wordCount;
  final bool aiReady;
  final ParsedInstruction? detectedInstruction;
  final ValueChanged<String> onChanged;
  final VoidCallback onCopy;
  final VoidCallback onFocusEditor;
  final VoidCallback onShare;
  final ValueChanged<DraftRewriteAction> onRewrite;
  final VoidCallback onAiStudio;
  final VoidCallback onOpenTranslationStudio;
  final VoidCallback? onRunDetectedInstruction;
  final VoidCallback onClear;
  final ValueChanged<String> onQuickPunctuation;
  final ValueChanged<String> onQuickTranslate;

  static const _quickMarks = ['，', '。', '？', '！', '……'];
  static const _translateShortcuts = <String, String>{
    'en': '英文',
    'ja': '日文',
    'fr': '法文',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasInstruction = detectedInstruction?.hasInstruction == true;
    final canOperate = controller.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('转录结果', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text(title, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            _MetricChip(icon: Icons.notes, value: '$wordCount 字'),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _InfoPill(
              label: modelLabel,
              icon: Icons.graphic_eq,
              highlighted: true,
            ),
            _InfoPill(label: durationLabel, icon: Icons.timelapse),
            _InfoPill(label: languageLabel, icon: Icons.language),
          ],
        ),
        if (hasInstruction) ...[
          const SizedBox(height: 14),
          _InstructionBanner(
            instruction: detectedInstruction!,
            onRun: onRunDetectedInstruction,
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          maxLines: 10,
          minLines: 7,
          decoration: const InputDecoration(
            hintText: '识别完成后，文本会出现在这里，你可以继续润色。',
          ),
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.4,
          children: [
            _ActionTile(
              icon: Icons.copy_all_outlined,
              label: '复制文本',
              subtitle: '一键放进剪贴板',
              onTap: canOperate ? onCopy : null,
              highlighted: true,
            ),
            _ActionTile(
              icon: Icons.edit_outlined,
              label: '继续编辑',
              subtitle: '回到文本框修改',
              onTap: canOperate ? onFocusEditor : null,
            ),
            _ActionTile(
              icon: Icons.ios_share_outlined,
              label: '导出 / 分享',
              subtitle: 'TXT、PDF 或系统分享',
              onTap: canOperate ? onShare : null,
            ),
            _ActionTile(
              icon: Icons.auto_awesome,
              label: 'AI 整理',
              subtitle: '润色、总结、翻译',
              onTap: canOperate ? onAiStudio : null,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('快捷翻译', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _InfoPill(
              label: '原文 · $languageLabel',
              icon: Icons.article_outlined,
            ),
            ..._translateShortcuts.entries.map(
              (entry) => _ShortcutChip(
                label: entry.value,
                icon: Icons.translate,
                enabled: aiReady && canOperate,
                onTap: () => onQuickTranslate(entry.key),
              ),
            ),
            _ShortcutChip(
              label: '更多语言',
              icon: Icons.more_horiz,
              enabled: aiReady && canOperate,
              onTap: onOpenTranslationStudio,
            ),
          ],
        ),
        if (!aiReady) ...[
          const SizedBox(height: 8),
          Text('翻译快捷入口需要先在设置中配置 AI Key。', style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 16),
        Text('快捷标点', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _quickMarks
              .map(
                (mark) => OutlinedButton(
                  onPressed: canOperate ? () => onQuickPunctuation(mark) : null,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(54, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: Text(mark),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        Text('快捷整理', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: draftRewriteOptions
              .map(
                (option) => OutlinedButton.icon(
                  onPressed: canOperate ? () => onRewrite(option.action) : null,
                  icon: Icon(option.icon, size: 18),
                  label: Text(option.label),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        Text(
          '交互参考 docs/voice-input-app.html，保留了输入法式的预览、复制、翻译和 AI 整理链路。',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            TextButton(
              onPressed: canOperate ? onClear : null,
              child: const Text('丢弃本稿'),
            ),
            const Spacer(),
            FilledButton(
              onPressed: canOperate ? onShare : null,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text('发送 / 导出'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ModeBar extends StatelessWidget {
  const _ModeBar({
    required this.settings,
    required this.isRecording,
    required this.hasDraft,
  });

  final SettingsState settings;
  final bool isRecording;
  final bool hasDraft;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: _ModeItem(
                icon: Icons.record_voice_over_outlined,
                title: languageOptions[settings.languageCode] ?? '语言',
                subtitle: _sttModeDescription(settings),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ModeItem(
                icon: Icons.auto_fix_high,
                title: settings.smartPunctuation ? '标点自动' : '标点手动',
                subtitle: hasDraft
                    ? '结果可继续整理'
                    : isRecording
                    ? '实时整理中'
                    : '句读已启用',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeItem extends StatelessWidget {
  const _ModeItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeatureShowcase extends StatelessWidget {
  const _FeatureShowcase({
    required this.hasDraft,
    required this.lexiconCount,
    required this.onOpenLexicon,
    required this.onOpenPunctuation,
    required this.onOpenSync,
    required this.onOpenSkins,
  });

  final bool hasDraft;
  final int lexiconCount;
  final VoidCallback onOpenLexicon;
  final VoidCallback onOpenPunctuation;
  final VoidCallback onOpenSync;
  final VoidCallback onOpenSkins;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            hasDraft ? '继续完善输入体验' : '输入增强',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 12),
        _FeatureCard(
          icon: Icons.auto_stories_outlined,
          title: '个性化词库',
          subtitle: lexiconCount == 0
              ? '先把昵称、产品名和行业术语教给 app，识别结果会更稳。'
              : '已配置 $lexiconCount 条专属纠错规则，转写时会自动替换。',
          onTap: onOpenLexicon,
        ),
        const SizedBox(height: 12),
        _FeatureCard(
          icon: Icons.auto_awesome,
          title: '智能标点',
          subtitle: '按你的偏好补全句号、问号、感叹号，让成稿更像手打。',
          onTap: onOpenPunctuation,
        ),
        const SizedBox(height: 12),
        _FeatureCard(
          icon: Icons.cloud_sync_outlined,
          title: '云端同步',
          subtitle: '同步个人词库、输入习惯和设置，跨设备接着说。',
          onTap: onOpenSync,
        ),
        const SizedBox(height: 12),
        _FeatureCard(
          icon: Icons.palette_outlined,
          title: '皮肤中心',
          subtitle: '提供多套轻国风配色，界面会随皮肤即时切换。',
          onTap: onOpenSkins,
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WaveformPlaceholder extends StatelessWidget {
  const _WaveformPlaceholder();

  static const _heights = <double>[
    12,
    18,
    26,
    34,
    28,
    40,
    48,
    42,
    30,
    22,
    18,
    14,
  ];

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return SizedBox(
      height: 76,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _heights
            .map(
              (height) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 6,
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    colors: [
                      primary.withValues(alpha: 0.26),
                      primary.withValues(alpha: 0.76),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _CompactActionButton extends StatelessWidget {
  const _CompactActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: highlighted ? primary : null,
        side: BorderSide(
          color: highlighted ? primary.withValues(alpha: 0.28) : kPaperLine,
        ),
        backgroundColor: highlighted
            ? primary.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.42),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _InstructionBanner extends StatelessWidget {
  const _InstructionBanner({required this.instruction, required this.onRun});

  final ParsedInstruction instruction;
  final VoidCallback? onRun;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final target = _translationLabel(instruction.targetLanguage);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withValues(alpha: 0.26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_fix_high, color: primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  target == null
                      ? '已识别指令：${_instructionLabel(instruction.kind)}'
                      : '已识别指令：${_instructionLabel(instruction.kind)} → $target',
                  style: TextStyle(
                    color: primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (onRun != null)
                TextButton(onPressed: onRun, child: const Text('立即整理')),
            ],
          ),
          if (instruction.payload.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              instruction.payload,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: highlighted
                ? primary.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: highlighted ? primary.withValues(alpha: 0.24) : kPaperLine,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(999),
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: kPaperLine),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: primary),
              const SizedBox(width: 6),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.label,
    required this.icon,
    this.highlighted = false,
  });

  final String label;
  final IconData icon;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: highlighted
            ? primary.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted ? primary.withValues(alpha: 0.18) : kPaperLine,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: primary),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kPaperLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(value, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _InfoPillData {
  const _InfoPillData({
    required this.label,
    required this.icon,
    this.highlighted = false,
  });

  final String label;
  final IconData icon;
  final bool highlighted;
}

List<_InfoPillData> _buildHomeChips(SettingsState settings) {
  return [
    _InfoPillData(
      label: _sttModelLabel(settings),
      icon: Icons.graphic_eq,
      highlighted: true,
    ),
    _InfoPillData(label: settings.sampleRate.label, icon: Icons.hdr_strong),
    _InfoPillData(
      label: settings.aiEnabled ? settings.aiProvider.label : 'AI 关闭',
      icon: Icons.auto_awesome,
    ),
  ];
}

String _sttModelLabel(SettingsState settings) {
  return switch (settings.provider) {
    SttProvider.whisper => settings.groqModel.id,
    SttProvider.google => 'Google Speech',
    SttProvider.onDevice => 'On-device STT',
  };
}

String _sttModeDescription(SettingsState settings) {
  return switch (settings.provider) {
    SttProvider.whisper => '云端增强转写',
    SttProvider.google => '代理识别',
    SttProvider.onDevice => '本地实时识别',
  };
}

String _recordingTitle(DateTime? createdAt) {
  final value = createdAt ?? DateTime.now();
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '录音_$year$month${day}_$hour$minute';
}

String _formatDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '$minutes:${remainder.toString().padLeft(2, '0')}';
}

String _instructionLabel(AiRewriteKind? kind) {
  return switch (kind) {
    AiRewriteKind.cleanFillers => '去口语',
    AiRewriteKind.formal => '更正式',
    AiRewriteKind.concise => '压缩',
    AiRewriteKind.paragraph => '分段',
    AiRewriteKind.todo => '提炼待办',
    AiRewriteKind.translate => '翻译',
    AiRewriteKind.summarize => '总结',
    AiRewriteKind.custom => '自定义指令',
    null => '整理',
  };
}

String? _translationLabel(String? code) {
  return switch (code) {
    'en' || 'en-US' => '英文',
    'zh-CN' || 'zh' => '中文',
    'zh-TW' => '繁体中文',
    'ja' || 'ja-JP' => '日文',
    'fr' || 'fr-FR' => '法文',
    'es' || 'es-ES' => '西班牙文',
    'de' || 'de-DE' => '德文',
    _ => code,
  };
}
