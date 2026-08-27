import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local storage (Hive) before building the app.
  await bootstrap();

  // ProviderScope makes Riverpod available to the whole widget tree.
  runApp(const ProviderScope(child: AnimeWatcherApp()));
}
