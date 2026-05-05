import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/recording/recording_page.dart';
import 'features/settings/about_page.dart';
import 'features/settings/cloud_sync_page.dart';
import 'features/settings/personal_lexicon_page.dart';
import 'features/settings/punctuation_page.dart';
import 'features/settings/settings_page.dart';
import 'features/settings/settings_provider.dart';
import 'features/settings/skin_center_page.dart';
import 'features/shared/theme.dart';
import 'features/shared/widgets/tab_bar.dart';
import 'features/transcript/history_page.dart';
import 'features/transcript/transcript_detail_sheet.dart';

class VoxaApp extends ConsumerStatefulWidget {
  const VoxaApp({super.key});

  @override
  ConsumerState<VoxaApp> createState() => _VoxaAppState();
}

class _VoxaAppState extends ConsumerState<VoxaApp> {
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
      GoRoute(
        path: '/settings/lexicon',
        builder: (context, state) => const PersonalLexiconPage(),
      ),
      GoRoute(
        path: '/settings/punctuation',
        builder: (context, state) => const PunctuationPage(),
      ),
      GoRoute(
        path: '/settings/sync',
        builder: (context, state) => const CloudSyncPage(),
      ),
      GoRoute(
        path: '/settings/skins',
        builder: (context, state) => const SkinCenterPage(),
      ),
      GoRoute(
        path: '/settings/about',
        builder: (context, state) => const AboutPage(),
      ),
      GoRoute(
        path: '/transcript/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return _BottomSheetPage<void>(
            child: TranscriptDetailSheet(transcriptId: id),
          );
        },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp.router(
      title: 'chivoice',
      debugShowCheckedModeBanner: false,
      theme: voxaTheme(settings.skin),
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

class _BottomSheetPage<T> extends Page<T> {
  const _BottomSheetPage({required this.child});

  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) {
    return DialogRoute<T>(
      context: context,
      barrierColor: Colors.black54,
      settings: this,
      builder: (context) => child,
    );
  }
}
