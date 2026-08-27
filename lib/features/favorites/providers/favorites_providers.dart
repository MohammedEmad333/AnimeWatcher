import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../shared/models/anime.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/favorites_local_datasource.dart';
import '../data/favorites_remote_datasource.dart';
import '../data/favorites_repository.dart';

final _favoritesLocalDataSourceProvider = Provider<FavoritesLocalDataSource>(
  (ref) => FavoritesLocalDataSource(),
);

final _favoritesRemoteDataSourceProvider = Provider<FavoritesRemoteDataSource>(
  (ref) => FavoritesRemoteDataSource(ref.watch(dioClientProvider)),
);

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => FavoritesRepository(
    ref.watch(_favoritesRemoteDataSourceProvider),
    ref.watch(_favoritesLocalDataSourceProvider),
  ),
);

/// Cloud-backed favorites list exposed as `AsyncValue<List<Anime>>` so the
/// Favorites grid can render Loading / Success / Error uniformly.
///
/// The list is kept in sync with the authentication state (see the provider
/// below): it loads from the cloud when the user signs in and clears on
/// sign-out. Mutations update the cloud, the local cache and this in-memory
/// state together.
class FavoritesController extends StateNotifier<AsyncValue<List<Anime>>> {
  FavoritesController(this._repository)
      : super(const AsyncValue.loading());

  final FavoritesRepository _repository;

  List<Anime> get _current => state.valueOrNull ?? const [];

  bool isFavorite(String animeId) => _current.any((a) => a.id == animeId);

  /// Loads favorites from the cloud, warm-starting from the local cache and
  /// falling back to it if the network call fails.
  Future<void> refresh() async {
    final cached = _repository.cachedFavorites();
    if (cached.isNotEmpty && state.valueOrNull == null) {
      state = AsyncValue.data(cached);
    }

    final result = await AsyncValue.guard(_repository.getFavorites);
    // Prefer showing cached data over a hard error when we have something.
    state = (result.hasError && cached.isNotEmpty)
        ? AsyncValue.data(cached)
        : result;
  }

  /// Clears state on sign-out.
  void reset() => state = const AsyncValue.data(<Anime>[]);

  /// Adds [anime] to the cloud favorites; throws a [Failure] on error.
  Future<void> add(Anime anime) async {
    await _repository.add(anime);
    if (!isFavorite(anime.id)) {
      state = AsyncValue.data([anime, ..._current]);
    }
  }

  /// Removes an anime from the cloud favorites; throws a [Failure] on error.
  Future<void> remove(String animeId) async {
    await _repository.remove(animeId);
    state = AsyncValue.data(
      [..._current]..removeWhere((a) => a.id == animeId),
    );
  }

  Future<void> toggle(Anime anime) =>
      isFavorite(anime.id) ? remove(anime.id) : add(anime);
}

final favoritesProvider =
    StateNotifierProvider<FavoritesController, AsyncValue<List<Anime>>>(
  (ref) {
    final controller =
        FavoritesController(ref.watch(favoritesRepositoryProvider));

    // Reload favorites when the user signs in; clear them on sign-out.
    ref.listen<bool>(
      isAuthenticatedProvider,
      (previous, isAuthenticated) {
        if (isAuthenticated) {
          controller.refresh();
        } else {
          controller.reset();
        }
      },
      fireImmediately: true,
    );

    return controller;
  },
);

/// Whether a given anime is currently in the user's favorites.
final isFavoriteProvider = Provider.autoDispose.family<bool, String>(
  (ref, animeId) => ref
      .watch(favoritesProvider)
      .valueOrNull
      ?.any((a) => a.id == animeId) ??
      false,
);
