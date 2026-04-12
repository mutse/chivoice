import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/recording/recording_page.dart';
import 'features/settings/settings_page.dart';
import 'features/shared/theme.dart';
import 'features/shared/widgets/tab_bar.dart';
import 'features/transcript/history_page.dart';

class VoxaApp extends StatefulWidget {
  const VoxaApp({super.key});

  @override
  State<VoxaApp> createState() => _VoxaAppState();
}

class _VoxaAppState extends State<VoxaApp> {
  late final GoRouter _router = GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return VoxaScaffold(location: state.uri.toString(), child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const RecordingPage(),
          ),
          GoRoute(
            path: '/history',
            builder: (context, state) => const HistoryPage(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Voxa',
      debugShowCheckedModeBanner: false,
      theme: voxaTheme(),
      routerConfig: _router,
    );
  }
}

class VoxaScaffold extends StatelessWidget {
  const VoxaScaffold({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: VoxaTabBar(
        currentIndex: switch (location) {
          '/history' => 1,
          '/settings' => 2,
          _ => 0,
        },
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/');
            case 1:
              context.go('/history');
            case 2:
              context.go('/settings');
          }
        },
      ),
    );
  }
}
