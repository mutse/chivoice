import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/widgets/ink_wash_background.dart';
import 'settings_provider.dart';

class SkinCenterPage extends ConsumerWidget {
  const SkinCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('皮肤中心')),
      body: InkWashBackground(
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.84,
          ),
          itemCount: AppSkin.values.length,
          itemBuilder: (context, index) {
            final skin = AppSkin.values[index];
            final selected = skin == settings.skin;

            return InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => notifier.updateSkin(skin),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFFFFCF8),
                                Color(
                                  skin.secondaryValue,
                                ).withValues(alpha: 0.34),
                                Color(skin.primaryValue).withValues(alpha: 0.2),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                right: 12,
                                top: 12,
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Color(skin.primaryValue),
                                      width: 2.4,
                                    ),
                                    color: Colors.white.withValues(alpha: 0.75),
                                  ),
                                  child: Icon(
                                    Icons.mic,
                                    color: Color(skin.primaryValue),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 16,
                                bottom: 16,
                                child: Container(
                                  width: 72,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    color: Color(
                                      skin.primaryValue,
                                    ).withValues(alpha: 0.18),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              skin.label,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (selected)
                            Icon(
                              Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _skinDescription(skin),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static String _skinDescription(AppSkin skin) {
    return switch (skin) {
      AppSkin.bamboo => '米白宣纸搭配青竹绿，最接近参考稿气质。',
      AppSkin.ink => '更克制的烟墨灰，适合长时间输入。',
      AppSkin.amber => '暖砂金调，视觉更柔和。',
      AppSkin.pine => '深浅松影层次，更稳重。',
      AppSkin.frost => '月白清冷，界面更通透。',
      AppSkin.dusk => '带一点暮岚紫灰，适合夜晚阅读。',
    };
  }
}
