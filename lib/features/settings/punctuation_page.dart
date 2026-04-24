import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/widgets/ink_wash_background.dart';
import 'settings_provider.dart';

class PunctuationPage extends ConsumerWidget {
  const PunctuationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('标点设置')),
      body: InkWashBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: settings.smartPunctuation,
                      onChanged: notifier.toggleSmartPunctuation,
                      title: const Text('标点自动添加'),
                      subtitle: const Text('智能识别语句停顿，自动补全句读。'),
                    ),
                    const Divider(height: 24),
                    _PunctuationSlider(
                      label: '句号',
                      value: settings.periodStrength,
                      lowLabel: '较少',
                      highLabel: '更多',
                      onChanged: notifier.updatePeriodStrength,
                    ),
                    _PunctuationSlider(
                      label: '逗号',
                      value: settings.commaStrength,
                      lowLabel: '轻停顿',
                      highLabel: '更细腻',
                      onChanged: notifier.updateCommaStrength,
                    ),
                    _PunctuationSlider(
                      label: '问号',
                      value: settings.questionStrength,
                      lowLabel: '保守',
                      highLabel: '敏感',
                      onChanged: notifier.updateQuestionStrength,
                    ),
                    _PunctuationSlider(
                      label: '感叹号',
                      value: settings.exclamationStrength,
                      lowLabel: '克制',
                      highLabel: '热烈',
                      onChanged: notifier.updateExclamationStrength,
                    ),
                    _PunctuationSlider(
                      label: '省略号',
                      value: settings.ellipsisStrength,
                      lowLabel: '少用',
                      highLabel: '更有语气',
                      onChanged: notifier.updateEllipsisStrength,
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: notifier.resetPunctuationTuning,
                      child: const Text('恢复默认'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PunctuationSlider extends StatelessWidget {
  const _PunctuationSlider({
    required this.label,
    required this.value,
    required this.lowLabel,
    required this.highLabel,
    required this.onChanged,
  });

  final String label;
  final double value;
  final String lowLabel;
  final String highLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(
                value >= 0.7
                    ? highLabel
                    : value <= 0.3
                    ? lowLabel
                    : '适中',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          Slider(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
