import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  'Used for Groq cloud transcription with whisper-large-v3.',
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
