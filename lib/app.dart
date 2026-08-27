import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/home/presentation/home_screen.dart';

/// Root application widget.
class AnimeWatcherApp extends StatelessWidget {
  const AnimeWatcherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AnimeWatcher',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const HomeScreen(),
    );
  }
}
