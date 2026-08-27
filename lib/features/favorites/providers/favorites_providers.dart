import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/anime.dart';
import '../data/favorites_local_datasource.dart';
import '../data/favorites_repository.dart';

final _favoritesDataSourceProvider = Provider<FavoritesLocalDataSource>(
  (ref) => FavoritesLocalDataSource(),
);

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => FavoritesRepository(ref.watch(_favoritesDataSourceProvider)),
);

/// Holds the current list of favorited anime and mutates local storage.
///
/// The whole list is kept in memory as the single source of truth for the UI;
/// every add/remove writes through to Hive and refreshes the in-memory state,
/// so the Favorites grid and per-anime toggle buttons stay in sync.
class FavoritesNotifier extends StateNotifier<List<Anime>> {
  FavoritesNotifier(this._repository) : super(const []) {
    _load();
  }

  final FavoritesRepository _repository;

  void _load() => state = _repository.getFavorites();

  bool isFavorite(String animeId) => state.any((a) => a.id == animeId);

  Future<void> toggle(Anime anime) async {
    if (isFavorite(anime.id)) {
      await _repository.remove(anime.id);
    } else {
      await _repository.add(anime);
    }
    _load();
  }

  Future<void> remove(String animeId) async {
    await _repository.remove(animeId);
    _load();
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, List<Anime>>(
  (ref) => FavoritesNotifier(ref.watch(favoritesRepositoryProvider)),
);

/// Convenience selector: is a given anime currently favorited?
final isFavoriteProvider = Provider.autoDispose.family<bool, String>(
  (ref, animeId) =>
      ref.watch(favoritesProvider).any((a) => a.id == animeId),
);
