import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/ai/openai_compatible_client.dart';
import '../../services/api_proxy.dart';
import '../../services/stt/whisper_stt.dart';
import '../shared/theme.dart';
import '../shared/widgets/ink_wash_background.dart';
import 'settings_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _isTestingGroq = false;
  bool _isTestingAi = false;
  bool _showAiKey = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: InkWashBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.mic_none_rounded,
                        size: 28,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'chivoice',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${languageOptions[settings.languageCode]} · ${settings.skin.label} · ${_providerLabel(settings.provider)}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _GroupCard(
              children: [
                _SettingTile(
                  icon: Icons.language,
                  title: '语言选择',
                  trailing:
                      languageOptions[settings.languageCode] ??
                      settings.languageCode,
                  onTap: () => _pickLanguage(context, notifier, settings),
                ),
                _SettingTile(
                  icon: Icons.tips_and_updates_outlined,
                  title: '识别模式',
                  trailing: _providerShortLabel(settings.provider),
                  onTap: () => _pickProvider(context, notifier, settings),
                ),
                _SettingTile(
                  icon: Icons.more_time,
                  title: '标点设置',
                  trailing: settings.smartPunctuation ? '自动添加' : '手动',
                  onTap: () => context.push('/settings/punctuation'),
                ),
                _SettingTile(
                  icon: Icons.auto_stories_outlined,
                  title: '个性化词库',
                  trailing: settings.personalLexicon.isEmpty
                      ? '未配置'
                      : '${settings.personalLexicon.length} 条',
                  onTap: () => context.push('/settings/lexicon'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _GroupCard(
              children: [
                _SettingTile(
                  icon: Icons.cloud_sync_outlined,
                  title: '云端同步',
                  trailing: settings.lastSyncAt == null ? '未同步' : '已开启',
                  onTap: () => context.push('/settings/sync'),
                ),
                _SettingTile(
                  icon: Icons.palette_outlined,
                  title: '皮肤中心',
                  trailing: settings.skin.label,
                  onTap: () => context.push('/settings/skins'),
                ),
                _SettingTile(
                  icon: Icons.help_outline,
                  title: '帮助与反馈',
                  trailing: '查看',
                  onTap: () => _showSupportDialog(context),
                ),
                _SettingTile(
                  icon: Icons.info_outline,
                  title: '关于我们',
                  trailing: '版本 1.0.0',
                  onTap: () => context.push('/settings/about'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _AiSection(
              settings: settings,
              notifier: notifier,
              showKey: _showAiKey,
              onToggleKey: () =>
                  setState(() => _showAiKey = !_showAiKey),
              isTesting: _isTestingAi,
              onTest: () => _testAiConnection(context, settings),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '进阶识别配置',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '保留现有识别能力，方便你继续使用 Groq Whisper、Google 代理或本地识别。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: settings.groqApiKey,
                      decoration: const InputDecoration(
                        labelText: 'Groq API Key',
                        hintText: 'gsk_...',
                      ),
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      onChanged: notifier.updateGroqApiKey,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<GroqWhisperModel>(
                      initialValue: settings.groqModel,
                      decoration: const InputDecoration(
                        labelText: 'Groq Whisper 模型',
                      ),
                      items: GroqWhisperModel.values
                          .map(
                            (model) => DropdownMenuItem(
                              value: model,
                              child: Text(model.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          notifier.updateGroqModel(value);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      settings.groqModel.description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      initialValue: settings.proxyUrl,
                      decoration: const InputDecoration(
                        labelText: 'Google 代理地址',
                        hintText: 'https://your-proxy.example.com',
                      ),
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      enableSuggestions: false,
                      onChanged: notifier.updateProxyUrl,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _isTestingGroq
                          ? null
                          : () => _testGroqConnection(context, settings),
                      icon: _isTestingGroq
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.network_check),
                      label: Text(_isTestingGroq ? '测试中…' : '测试 Groq 连接'),
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

  Future<void> _pickLanguage(
    BuildContext context,
    SettingsNotifier notifier,
    SettingsState settings,
  ) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _SelectionSheet<String>(
        title: '语言选择',
        currentValue: settings.languageCode,
        options: languageOptions.entries
            .map(
              (entry) => _SelectionItem(
                value: entry.key,
                title: entry.value,
                subtitle: entry.key,
              ),
            )
            .toList(),
      ),
    );

    if (picked != null) {
      notifier.updateLanguage(picked);
    }
  }

  Future<void> _pickProvider(
    BuildContext context,
    SettingsNotifier notifier,
    SettingsState settings,
  ) async {
    final picked = await showModalBottomSheet<SttProvider>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _SelectionSheet<SttProvider>(
        title: '识别模式',
        currentValue: settings.provider,
        options: const [
          _SelectionItem(
            value: SttProvider.whisper,
            title: '智能模式',
            subtitle: 'Groq Whisper 云端增强',
          ),
          _SelectionItem(
            value: SttProvider.google,
            title: '代理模式',
            subtitle: '通过 Google STT 代理识别',
          ),
          _SelectionItem(
            value: SttProvider.onDevice,
            title: '即时模式',
            subtitle: '完全使用本地识别',
          ),
        ],
      ),
    );

    if (picked != null) {
      notifier.updateProvider(picked);
    }
  }

  void _showSupportDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('帮助与反馈'),
        content: const Text(
          '这版改造重点优化了输入法式语音流程。如果你继续迭代，可以把常用短语、联系人昵称和行业术语加入个性化词库。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _testAiConnection(
    BuildContext context,
    SettingsState settings,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (settings.aiApiKey.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('请先填写 AI API Key。')),
      );
      return;
    }
    setState(() => _isTestingAi = true);
    try {
      final client = OpenAiCompatibleClient(
        apiProxy: ApiProxy(
          baseUrl: settings.aiBaseUrl.isEmpty
              ? settings.aiProvider.defaultBaseUrl
              : settings.aiBaseUrl,
          headers: {'Authorization': 'Bearer ${settings.aiApiKey.trim()}'},
        ),
        model: settings.aiModel.isEmpty
            ? settings.aiProvider.defaultModel
            : settings.aiModel,
      );
      final message = await client.verifyConnection();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } on AiRemoteException catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('AI 测试失败：${error.message}')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text('AI 测试失败：$error')));
    } finally {
      if (mounted) {
        setState(() => _isTestingAi = false);
      }
    }
  }

  Future<void> _testGroqConnection(
    BuildContext context,
    SettingsState settings,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (settings.groqApiKey.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('请先填写 Groq API Key。')),
      );
      return;
    }

    setState(() {
      _isTestingGroq = true;
    });

    try {
      final service = WhisperStt(
        apiProxy: ApiProxy(
          baseUrl: groqOpenAiCompatibleBaseUrl,
          headers: {'Authorization': 'Bearer ${settings.groqApiKey}'},
        ),
        model: settings.groqModel,
      );
      final message = await service.verifyConnection();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } on SttRemoteException catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Groq 测试失败：${error.message}')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text('Groq 测试失败：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _isTestingGroq = false;
        });
      }
    }
  }

  static String _providerLabel(SttProvider provider) {
    return switch (provider) {
      SttProvider.whisper => 'Groq Whisper',
      SttProvider.google => 'Google 代理',
      SttProvider.onDevice => '本地识别',
    };
  }

  static String _providerShortLabel(SttProvider provider) {
    return switch (provider) {
      SttProvider.whisper => '智能模式',
      SttProvider.google => '代理模式',
      SttProvider.onDevice => '即时模式',
    };
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children:
            children
                .expand((child) => [child, const Divider(height: 1)])
                .toList()
              ..removeLast(),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 18, color: primary),
      ),
      title: Text(title),
      subtitle: Text(trailing, style: Theme.of(context).textTheme.bodySmall),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _AiSection extends StatelessWidget {
  const _AiSection({
    required this.settings,
    required this.notifier,
    required this.showKey,
    required this.onToggleKey,
    required this.isTesting,
    required this.onTest,
  });

  final SettingsState settings;
  final SettingsNotifier notifier;
  final bool showKey;
  final VoidCallback onToggleKey;
  final bool isTesting;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'AI 智能',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Switch(
                  value: settings.aiEnabled,
                  onChanged: notifier.toggleAiEnabled,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '录音整理后可调用大模型润色、压缩或翻译；关闭后仅使用本地规则。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AiProvider.values.map((p) {
                final isActive = settings.aiProvider == p;
                return ChoiceChip(
                  label: Text(p.label),
                  selected: isActive,
                  onSelected: settings.aiEnabled
                      ? (_) => notifier.updateAiProvider(p)
                      : null,
                  selectedColor: primary.withValues(alpha: 0.18),
                  side: BorderSide(
                    color: isActive ? primary : kPaperLine,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: ValueKey('ai-baseUrl-${settings.aiProvider.name}'),
              initialValue: settings.aiBaseUrl,
              enabled: settings.aiEnabled,
              decoration: const InputDecoration(
                labelText: 'API 地址',
                hintText: 'https://api.example.com/v1',
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: notifier.updateAiBaseUrl,
            ),
            const SizedBox(height: 14),
            TextFormField(
              initialValue: settings.aiApiKey,
              enabled: settings.aiEnabled,
              decoration: InputDecoration(
                labelText: 'API Key',
                hintText: 'sk-...',
                suffixIcon: IconButton(
                  icon: Icon(
                    showKey ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: onToggleKey,
                ),
              ),
              obscureText: !showKey,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: notifier.updateAiApiKey,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: ValueKey('ai-model-${settings.aiProvider.name}'),
              initialValue: settings.aiModel,
              enabled: settings.aiEnabled,
              decoration: const InputDecoration(
                labelText: '模型名称',
                hintText: 'llama-3.3-70b-versatile',
              ),
              autocorrect: false,
              enableSuggestions: false,
              onChanged: notifier.updateAiModel,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: (!settings.aiEnabled || isTesting) ? null : onTest,
              icon: isTesting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.network_check),
              label: Text(isTesting ? '测试中…' : '测试 AI 连接'),
            ),
            const SizedBox(height: 8),
            Text(
              'API Key 仅保存在本设备，不会上传 ChiVoice 服务器。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionItem<T> {
  const _SelectionItem({
    required this.value,
    required this.title,
    required this.subtitle,
  });

  final T value;
  final String title;
  final String subtitle;
}

class _SelectionSheet<T> extends StatelessWidget {
  const _SelectionSheet({
    required this.title,
    required this.currentValue,
    required this.options,
  });

  final String title;
  final T currentValue;
  final List<_SelectionItem<T>> options;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return SafeArea(
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
            const SizedBox(height: 18),
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            ...options.map(
              (item) => ListTile(
                onTap: () => Navigator.pop(context, item.value),
                title: Text(item.title),
                subtitle: Text(item.subtitle),
                trailing: item.value == currentValue
                    ? Icon(Icons.check_circle, color: primary)
                    : null,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
