import '../../../core/error/failures.dart';
import '../../../shared/models/anime.dart';
import 'favorites_local_datasource.dart';

/// Repository for the locally-stored Favorites / Library.
///
/// Translates [CacheException]s from the datasource into [Failure]s.
class FavoritesRepository {
  const FavoritesRepository(this._local);

  final FavoritesLocalDataSource _local;

  List<Anime> getFavorites() => _guard(() => _local.getAll());

  bool isFavorite(String animeId) => _local.isFavorite(animeId);

  Future<void> add(Anime anime) => _guardAsync(() => _local.add(anime));

  Future<void> remove(String animeId) =>
      _guardAsync(() => _local.remove(animeId));

  T _guard<T>(T Function() action) {
    try {
      return action();
    } catch (e) {
      throw Failure.fromException(e);
    }
  }

  Future<T> _guardAsync<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      throw Failure.fromException(e);
    }
  }
}
