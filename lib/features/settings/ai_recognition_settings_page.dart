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
  bool _isTestingStt = false;
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
        _CloudRecognitionCard(
          settings: settings,
          notifier: notifier,
          isTestingStt: _isTestingStt,
          onTestStt: () => _testSttConnection(context, settings),
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

  Future<void> _testSttConnection(
    BuildContext context,
    SettingsState settings,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (settings.sttBaseUrl.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('请先填写 STT API 地址。')));
      return;
    }
    if (settings.sttApiKey.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('请先填写 STT API Key。')),
      );
      return;
    }
    if (settings.sttModelId.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('请先填写 STT 模型名称。')));
      return;
    }

    setState(() {
      _isTestingStt = true;
    });

    try {
      final service = WhisperStt(
        apiProxy: ApiProxy(
          baseUrl: settings.sttBaseUrl,
          headers: {'Authorization': 'Bearer ${settings.sttApiKey}'},
        ),
        providerLabel: settings.sttPreset.label,
        modelId: settings.sttModelId,
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
        SnackBar(content: Text('STT 测试失败：${error.message}')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text('STT 测试失败：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _isTestingStt = false;
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

class _CloudRecognitionCard extends StatelessWidget {
  const _CloudRecognitionCard({
    required this.settings,
    required this.notifier,
    required this.isTestingStt,
    required this.onTestStt,
  });

  final SettingsState settings;
  final SettingsNotifier notifier;
  final bool isTestingStt;
  final VoidCallback onTestStt;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('云端 STT 配置', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '支持继续使用 Groq，也支持填写国内兼容 STT 服务的 API 地址、密钥和模型名。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SttPreset.values.map((preset) {
                final isActive = settings.sttPreset == preset;
                return ChoiceChip(
                  label: Text(preset.label),
                  selected: isActive,
                  onSelected: (_) => notifier.updateSttPreset(preset),
                  selectedColor: primary.withValues(alpha: 0.18),
                  side: BorderSide(color: isActive ? primary : kPaperLine),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Text(
              settings.sttPreset.description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: ValueKey('stt-baseUrl-${settings.sttPreset.name}'),
              initialValue: settings.sttBaseUrl,
              decoration: InputDecoration(
                labelText: 'STT API 地址',
                hintText: settings.sttPreset.baseUrlHint,
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: notifier.updateSttBaseUrl,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: ValueKey('stt-apiKey-${settings.sttPreset.name}'),
              initialValue: settings.sttApiKey,
              decoration: const InputDecoration(
                labelText: 'STT API Key',
                hintText: 'sk-...',
              ),
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: notifier.updateSttApiKey,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: ValueKey('stt-model-${settings.sttPreset.name}'),
              initialValue: settings.sttModelId,
              decoration: InputDecoration(
                labelText: 'STT 模型名称',
                hintText: settings.sttPreset.modelHint,
              ),
              autocorrect: false,
              enableSuggestions: false,
              onChanged: notifier.updateSttModelId,
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
              onPressed: isTestingStt ? null : onTestStt,
              icon: isTestingStt
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.network_check),
              label: Text(isTestingStt ? '测试中…' : '测试 STT 连接'),
            ),
            const SizedBox(height: 8),
            Text(
              '国内服务如提供 OpenAI 兼容转写接口，可直接填写这里的地址、Key 和模型名。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
