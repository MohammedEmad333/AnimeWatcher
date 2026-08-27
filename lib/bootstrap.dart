import 'package:hive_flutter/hive_flutter.dart';

import 'features/favorites/data/favorites_local_datasource.dart';
import 'shared/models/anime.dart';

/// One-time app initialization performed before the UI is shown.
///
/// Currently sets up Hive: registers the [AnimeAdapter] and opens the
/// favorites box so [FavoritesLocalDataSource] can access it synchronously.
Future<void> bootstrap() async {
  await Hive.initFlutter();

  if (!Hive.isAdapterRegistered(AnimeAdapter().typeId)) {
    Hive.registerAdapter(AnimeAdapter());
  }

  await Hive.openBox<Anime>(FavoritesLocalDataSource.boxName);
}
