import 'package:chivoice/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('sidebar adapts to iPad rotation and narrow split view', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: '/settings/detail',
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              VoxaScaffold(location: state.uri.path, child: child),
          routes: [
            for (final path in [
              '/',
              '/history',
              '/settings',
              '/settings/detail',
            ])
              GoRoute(path: path, builder: (_, _) => Text('page: $path')),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    tester.view.physicalSize = const Size(834, 1194);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      2,
    );
    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.text('稿库'));
    await tester.pumpAndSettle();
    expect(find.text('page: /history'), findsOneWidget);
    tester.view.physicalSize = const Size(1194, 834);
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
      isTrue,
    );
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsNothing);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    expect(tester.takeException(), isNull);
  });
}
