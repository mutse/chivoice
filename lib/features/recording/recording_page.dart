import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'draft_rewrite.dart';
import '../settings/settings_provider.dart';
import '../shared/theme.dart';
import '../shared/widgets/ink_wash_background.dart';
import '../transcript/export_service.dart';
import '../transcript/export_sheet.dart';
import '../transcript/transcript_provider.dart';
import 'audio_recorder_service.dart';
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
  String? _lastRewriteSnapshot;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recording = ref.watch(recordingProvider);
    final settings = ref.watch(settingsProvider);
    final recorder = ref.watch(audioRecorderServiceProvider);

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('语音输入'),
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
              tooltip: '删除本稿',
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
                        elapsedSeconds: recording.elapsedSeconds,
                        onStop: () => ref
                            .read(recordingProvider.notifier)
                            .stopRecording(),
                      ),
                      RecordingStatus.processing => const _ProcessingState(
                        key: ValueKey('processing'),
                      ),
                      _ when hasDraft => _DraftState(
                        key: const ValueKey('draft'),
                        controller: _controller,
                        wordCount: recording.wordCount,
                        onChanged: (value) => ref
                            .read(recordingProvider.notifier)
                            .updateDraftText(value),
                        onShare: () => _openExportSheet(
                          context,
                          settings: settings,
                          recording: recording,
                        ),
                        onRewrite: (action) =>
                            _applyDraftRewrite(action, settings.languageCode),
                        onClear: () => ref
                            .read(recordingProvider.notifier)
                            .updateDraftText(''),
                        onQuickPunctuation: _appendQuickPunctuation,
                      ),
                      _ => _IdleState(
                        key: const ValueKey('idle'),
                        languageLabel:
                            languageOptions[settings.languageCode] ??
                            settings.languageCode,
                        punctuationEnabled: settings.smartPunctuation,
                        onStart: () => ref
                            .read(recordingProvider.notifier)
                            .startRecording(),
                      ),
                    },
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _ModeBar(
                settings: settings,
                isRecording: recording.status == RecordingStatus.recording,
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
    required this.punctuationEnabled,
    required this.onStart,
  });

  final String languageLabel;
  final bool punctuationEnabled;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text('轻声落字，开口即写', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 10),
        Text(
          '像输入法一样自然地说话，系统会自动整理为可发送的文本。',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 28),
        MicButton(isRecording: false, onPressed: onStart),
        const SizedBox(height: 16),
        const Text('点击说话'),
        const SizedBox(height: 24),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            _TagChip(icon: Icons.language, label: languageLabel),
            _TagChip(
              icon: Icons.auto_awesome,
              label: punctuationEnabled ? '标点自动' : '手动整理',
            ),
            const _TagChip(icon: Icons.cloud_done_outlined, label: '多端同步'),
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
    required this.elapsedSeconds,
    required this.onStop,
  });

  final AudioRecorderService recorder;
  final int elapsedSeconds;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        Text('倾听中…', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 10),
        Text(
          '保持自然语速即可，系统会先做本地转写，再补充最终识别结果。',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 28),
        WaveformWidget(
          amplitudeStream: recorder.amplitudeStream,
          activeColor: primary,
        ),
        const SizedBox(height: 22),
        _MetricChip(icon: Icons.timelapse, value: '${elapsedSeconds}s'),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: onStop,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Text('说完了'),
          ),
        ),
      ],
    );
  }
}

class _ProcessingState extends StatelessWidget {
  const _ProcessingState({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        const SizedBox(height: 12),
        SizedBox(
          width: 56,
          height: 56,
          child: CircularProgressIndicator(strokeWidth: 3, color: primary),
        ),
        const SizedBox(height: 20),
        Text('整理语音中', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 10),
        Text(
          '正在合并实时转写与最终识别结果，并根据你的偏好补全标点。',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _DraftState extends StatelessWidget {
  const _DraftState({
    super.key,
    required this.controller,
    required this.wordCount,
    required this.onChanged,
    required this.onShare,
    required this.onRewrite,
    required this.onClear,
    required this.onQuickPunctuation,
  });

  final TextEditingController controller;
  final int wordCount;
  final ValueChanged<String> onChanged;
  final VoidCallback onShare;
  final ValueChanged<DraftRewriteAction> onRewrite;
  final VoidCallback onClear;
  final ValueChanged<String> onQuickPunctuation;

  static const _quickMarks = ['，', '。', '？', '！', '……'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '识别结果',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            _MetricChip(icon: Icons.notes, value: '$wordCount 字'),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          onChanged: onChanged,
          maxLines: 8,
          minLines: 8,
          decoration: const InputDecoration(
            hintText: '识别完成后，文本会出现在这里，你可以继续润色。',
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _quickMarks
              .map(
                (mark) => OutlinedButton(
                  onPressed: () => onQuickPunctuation(mark),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(54, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: Text(mark),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 18),
        Text('快捷整理', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: draftRewriteOptions
              .map(
                (option) => OutlinedButton.icon(
                  onPressed: () => onRewrite(option.action),
                  icon: Icon(option.icon, size: 18),
                  label: Text(option.label),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        Text(
          '灵感参考豆包式语义整理，适合把语音稿顺手修成能直接发出去的文字。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            TextButton(onPressed: onClear, child: const Text('清空')),
            const Spacer(),
            FilledButton(
              onPressed: controller.text.trim().isEmpty ? null : onShare,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 28),
                child: Text('发送'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ModeBar extends StatelessWidget {
  const _ModeBar({required this.settings, required this.isRecording});

  final SettingsState settings;
  final bool isRecording;

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
                subtitle: switch (settings.provider) {
                  SttProvider.whisper => '云端增强',
                  SttProvider.google => '代理识别',
                  SttProvider.onDevice => '本地识别',
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ModeItem(
                icon: Icons.auto_fix_high,
                title: settings.smartPunctuation ? '标点自动' : '标点手动',
                subtitle: isRecording ? '实时整理中' : '句读已启用',
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
            hasDraft ? '继续完善输入体验' : '功能亮点',
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

class _TagChip extends StatelessWidget {
  const _TagChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: primary),
          const SizedBox(width: 6),
          Text(label),
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
