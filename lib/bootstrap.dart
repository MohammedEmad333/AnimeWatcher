import 'package:hive_flutter/hive_flutter.dart';

import 'features/auth/data/token_storage.dart';
import 'features/favorites/data/favorites_local_datasource.dart';
import 'shared/models/anime.dart';

/// The result of [bootstrap]: initialized singletons that must be injected into
/// the Riverpod graph (via provider overrides) in `main`.
class BootstrapResult {
  const BootstrapResult({required this.tokenStorage});

  final TokenStorage tokenStorage;
}

/// One-time app initialization performed before the UI is shown.
///
///  * Sets up Hive (registers the [AnimeAdapter] and opens the favorites cache).
///  * Creates and preloads [TokenStorage] so the JWT auth interceptor can
///    inject the token synchronously from the very first request.
Future<BootstrapResult> bootstrap() async {
  await Hive.initFlutter();

  if (!Hive.isAdapterRegistered(AnimeAdapter().typeId)) {
    Hive.registerAdapter(AnimeAdapter());
  }
  await Hive.openBox<Anime>(FavoritesLocalDataSource.boxName);

  final tokenStorage = TokenStorage();
  await tokenStorage.init();

  return BootstrapResult(tokenStorage: tokenStorage);
}
