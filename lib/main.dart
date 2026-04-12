import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Future.wait([
    Hive.openBox<dynamic>('settings'),
    Hive.openBox<dynamic>('transcripts'),
  ]);
  runApp(const ProviderScope(child: VoxaApp()));
}
