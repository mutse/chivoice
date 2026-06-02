import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/ai/openai_compatible_client.dart';
import '../../services/api_proxy.dart';
import '../../services/stt/whisper_stt.dart';
import '../shared/theme.dart';
import '../shared/widgets/ink_wash_background.dart';
import 'settings_provider.dart';

class AiRecognitionSettingsPage extends StatelessWidget {
  const AiRecognitionSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI识别配置')),
      body: InkWashBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: const [AiRecognitionSettingsSection()],
        ),
      ),
    );
  }
}

class AiRecognitionSettingsSection extends ConsumerStatefulWidget {
  const AiRecognitionSettingsSection({super.key});

  @override
  ConsumerState<AiRecognitionSettingsSection> createState() =>
      _AiRecognitionSettingsSectionState();
}

class _AiRecognitionSettingsSectionState
    extends ConsumerState<AiRecognitionSettingsSection> {
  bool _isTestingGroq = false;
  bool _isTestingAi = false;
  bool _showAiKey = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AiSection(
          settings: settings,
          notifier: notifier,
          showKey: _showAiKey,
          onToggleKey: () => setState(() => _showAiKey = !_showAiKey),
          isTesting: _isTestingAi,
          onTest: () => _testAiConnection(context, settings),
        ),
        const SizedBox(height: 16),
        _AdvancedRecognitionCard(
          settings: settings,
          notifier: notifier,
          isTestingGroq: _isTestingGroq,
          onTestGroq: () => _testGroqConnection(context, settings),
        ),
      ],
    );
  }

  Future<void> _testAiConnection(
    BuildContext context,
    SettingsState settings,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (settings.aiApiKey.trim().isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('请先填写 AI API Key。')));
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
                Text('AI 智能', style: Theme.of(context).textTheme.titleMedium),
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
                  side: BorderSide(color: isActive ? primary : kPaperLine),
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
                  icon: Icon(showKey ? Icons.visibility_off : Icons.visibility),
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

class _AdvancedRecognitionCard extends StatelessWidget {
  const _AdvancedRecognitionCard({
    required this.settings,
    required this.notifier,
    required this.isTestingGroq,
    required this.onTestGroq,
  });

  final SettingsState settings;
  final SettingsNotifier notifier;
  final bool isTestingGroq;
  final VoidCallback onTestGroq;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('进阶识别配置', style: Theme.of(context).textTheme.titleMedium),
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
              decoration: const InputDecoration(labelText: 'Groq Whisper 模型'),
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
              onPressed: isTestingGroq ? null : onTestGroq,
              icon: isTestingGroq
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.network_check),
              label: Text(isTestingGroq ? '测试中…' : '测试 Groq 连接'),
            ),
          ],
        ),
      ),
    );
  }
}
