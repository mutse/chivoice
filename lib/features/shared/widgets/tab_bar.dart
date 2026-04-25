import 'package:flutter/material.dart';

import '../theme.dart';

class VoxaTabBar extends StatelessWidget {
  const VoxaTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: kPaperLine),
          boxShadow: const [
            BoxShadow(
              blurRadius: 24,
              offset: Offset(0, 12),
              color: Color(0x14000000),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: onTap,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.mic_none), label: '语音'),
            NavigationDestination(icon: Icon(Icons.auto_stories), label: '稿库'),
            NavigationDestination(icon: Icon(Icons.tune), label: '设置'),
          ],
        ),
      ),
    );
  }
}
