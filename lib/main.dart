import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'bootstrap.dart';
import 'core/providers/core_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local storage (Hive) and secure token storage before the UI.
  final result = await bootstrap();

  runApp(
    ProviderScope(
      overrides: [
        // Inject the preloaded TokenStorage so the JWT interceptor is ready.
        tokenStorageProvider.overrideWithValue(result.tokenStorage),
      ],
      child: const AnimeWatcherApp(),
    ),
  );
}
