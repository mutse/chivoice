import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/widgets/ink_wash_background.dart';
import 'settings_provider.dart';

class CloudSyncPage extends ConsumerWidget {
  const CloudSyncPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final lastSync = settings.lastSyncAt;

    return Scaffold(
      appBar: AppBar(title: const Text('云端同步')),
      body: InkWashBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.8),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.38),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.cloud_done_outlined,
                        size: 42,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '已同步',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      lastSync == null
                          ? '还没有同步记录，点击下方按钮即可把当前偏好保存到云端。'
                          : '最近同步：${_formatSyncTime(lastSync.toLocal())}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 18),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: settings.syncPersonalLexicon,
                      onChanged: notifier.toggleSyncPersonalLexicon,
                      title: const Text('同步个人词库'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: settings.syncSettings,
                      onChanged: notifier.toggleSyncSettings,
                      title: const Text('同步设置项'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: settings.syncInputHabits,
                      onChanged: notifier.toggleSyncInputHabits,
                      title: const Text('同步输入习惯'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () {
                        notifier.markSyncedNow();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已完成一次同步。')),
                        );
                      },
                      child: const Text('立即同步'),
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

  static String _formatSyncTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} $hour:$minute';
  }
}
