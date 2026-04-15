import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/api_proxy.dart';
import '../../services/stt/whisper_stt.dart';
import 'settings_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _isTestingGroq = false;

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          _Section(
            title: 'Speech provider',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: SttProvider.values.map((provider) {
                return ChoiceChip(
                  selected: provider == settings.provider,
                  label: Text(switch (provider) {
                    SttProvider.whisper => 'Groq Whisper',
                    SttProvider.google => 'Google',
                    SttProvider.onDevice => 'On-device',
                  }),
                  onSelected: (_) => notifier.updateProvider(provider),
                );
              }).toList(),
            ),
          ),
          _Section(
            title: 'Groq API Key',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Used for Groq cloud transcription and connection checks.',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: settings.groqApiKey,
                  decoration: const InputDecoration(hintText: 'gsk_...'),
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  onChanged: notifier.updateGroqApiKey,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<GroqWhisperModel>(
                  initialValue: settings.groqModel,
                  decoration: const InputDecoration(
                    labelText: 'Groq Whisper Model',
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
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isTestingGroq
                        ? null
                        : () => _testGroqConnection(context, settings),
                    icon: _isTestingGroq
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.network_check),
                    label: Text(_isTestingGroq ? 'Testing...' : '测试 Groq 连接'),
                  ),
                ),
              ],
            ),
          ),
          _Section(
            title: 'Language',
            child: DropdownButtonFormField<String>(
              initialValue: settings.languageCode,
              items: languageOptions.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text('${entry.value} · ${entry.key}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  notifier.updateLanguage(value);
                }
              },
            ),
          ),
          _Section(
            title: 'Sample rate',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Slider(
                  value: SampleRate.values
                      .indexOf(settings.sampleRate)
                      .toDouble(),
                  min: 0,
                  max: 2,
                  divisions: 2,
                  label: settings.sampleRate.label,
                  onChanged: (value) => notifier.updateSampleRate(
                    SampleRate.values[value.round()],
                  ),
                ),
                Text(settings.sampleRate.label),
              ],
            ),
          ),
          _Section(
            title: 'Smart punctuation',
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: settings.smartPunctuation,
              onChanged: notifier.toggleSmartPunctuation,
              title: const Text('Enable automatic sentence cleanup'),
            ),
          ),
          if (settings.provider == SttProvider.google)
            _Section(
              title: 'Proxy URL',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Used for the Google STT proxy endpoint.'),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: settings.proxyUrl,
                    decoration: const InputDecoration(
                      hintText: 'https://your-proxy.example.com',
                    ),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    enableSuggestions: false,
                    onChanged: notifier.updateProxyUrl,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _testGroqConnection(
    BuildContext context,
    SettingsState settings,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (settings.groqApiKey.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Please add your Groq API key before testing.'),
        ),
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
        SnackBar(content: Text('Groq test failed: ${error.message}')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Groq test failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isTestingGroq = false;
        });
      }
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
