import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/widgets/ink_wash_background.dart';
import 'personal_lexicon.dart';
import 'settings_provider.dart';

class PersonalLexiconPage extends ConsumerWidget {
  const PersonalLexiconPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final entries = settings.personalLexicon;
    final enabledCount = entries.where((entry) => entry.enabled).length;

    return Scaffold(
      appBar: AppBar(title: const Text('个性化词库')),
      body: InkWashBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.auto_fix_high_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '把常错词先教给 app',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '例如把“小丽”自动改成“晓丽”，或把“api”改成“API”。',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _LexiconMetricChip(label: '已配置 ${entries.length} 条'),
                        _LexiconMetricChip(label: '当前启用 $enabledCount 条'),
                      ],
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () =>
                          _openLexiconEditor(context, notifier: notifier),
                      icon: const Icon(Icons.add),
                      label: const Text('新增纠错规则'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (entries.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      Icon(
                        Icons.menu_book_outlined,
                        size: 38,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '还没有词库规则',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '先把联系人昵称、产品名、行业术语加进来，识别结果会更像你平时真正想发出去的内容。',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              )
            else
              ...entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.spokenForm,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              Switch(
                                value: entry.enabled,
                                onChanged: (value) =>
                                    notifier.togglePersonalLexiconEntry(
                                      entry.id,
                                      value,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '识别为',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.writtenForm,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: () => _openLexiconEditor(
                                  context,
                                  notifier: notifier,
                                  entry: entry,
                                ),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('编辑'),
                              ),
                              TextButton.icon(
                                onPressed: () => notifier
                                    .deletePersonalLexiconEntry(entry.id),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('删除'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openLexiconEditor(
    BuildContext context, {
    required SettingsNotifier notifier,
    PersonalLexiconEntry? entry,
  }) async {
    final result = await showModalBottomSheet<_LexiconEditorResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LexiconEditorSheet(entry: entry),
    );

    if (result == null) {
      return;
    }

    if (entry == null) {
      notifier.addPersonalLexiconEntry(
        spokenForm: result.spokenForm,
        writtenForm: result.writtenForm,
      );
    } else {
      notifier.updatePersonalLexiconEntry(
        entry.copyWith(
          spokenForm: result.spokenForm,
          writtenForm: result.writtenForm,
        ),
      );
    }
  }
}

class _LexiconMetricChip extends StatelessWidget {
  const _LexiconMetricChip({required this.label});

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
      child: Text(label),
    );
  }
}

class _LexiconEditorResult {
  const _LexiconEditorResult({
    required this.spokenForm,
    required this.writtenForm,
  });

  final String spokenForm;
  final String writtenForm;
}

class _LexiconEditorSheet extends StatefulWidget {
  const _LexiconEditorSheet({this.entry});

  final PersonalLexiconEntry? entry;

  @override
  State<_LexiconEditorSheet> createState() => _LexiconEditorSheetState();
}

class _LexiconEditorSheetState extends State<_LexiconEditorSheet> {
  late final TextEditingController _spokenController = TextEditingController(
    text: widget.entry?.spokenForm ?? '',
  );
  late final TextEditingController _writtenController = TextEditingController(
    text: widget.entry?.writtenForm ?? '',
  );

  @override
  void dispose() {
    _spokenController.dispose();
    _writtenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 12, 12, bottomInset + 12),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.entry == null ? '新增纠错规则' : '编辑纠错规则',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '当你说出某个词时，app 会优先输出你设定的写法。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _spokenController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '你会怎么说',
                  hintText: '例如：小丽 / api / 张总',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _writtenController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: '希望输出成什么',
                  hintText: '例如：晓丽 / API / 张总监',
                ),
                onSubmitted: (_) => _submit(context),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => _submit(context),
                child: const Text('保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit(BuildContext context) {
    final spokenForm = _spokenController.text.trim();
    final writtenForm = _writtenController.text.trim();
    if (spokenForm.isEmpty || writtenForm.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先填写完整的词库规则。')));
      return;
    }

    Navigator.pop(
      context,
      _LexiconEditorResult(spokenForm: spokenForm, writtenForm: writtenForm),
    );
  }
}
