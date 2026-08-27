import '../../../core/error/failures.dart';
import '../../../shared/models/anime.dart';
import 'favorites_local_datasource.dart';
import 'favorites_remote_datasource.dart';

/// Repository for the user's cloud favorites, backed by a local Hive cache for
/// offline resilience.
///
/// Reads go to the cloud (authenticated); on success the result is mirrored to
/// the local cache so the Favorites grid can still render offline. Writes are
/// sent to the cloud and, on success, reflected in the cache. All errors are
/// translated into [Failure]s.
class FavoritesRepository {
  const FavoritesRepository(this._remote, this._local);

  final FavoritesRemoteDataSource _remote;
  final FavoritesLocalDataSource _local;

  /// Locally-cached favorites for an instant, offline-capable first paint.
  List<Anime> cachedFavorites() {
    try {
      return _local.getAll();
    } catch (_) {
      return const [];
    }
  }

  /// Fetches favorites from the cloud and refreshes the local cache.
  Future<List<Anime>> getFavorites() {
    return _guard(() async {
      final favorites = await _remote.getFavorites();
      await _local.replaceAll(favorites);
      return favorites;
    });
  }

  Future<void> add(Anime anime) {
    return _guard(() async {
      // Send the full anime so the backend can store title + cover_image.
      await _remote.addFavorite(anime);
      await _local.add(anime);
    });
  }

  Future<void> remove(String animeId) {
    return _guard(() async {
      await _remote.removeFavorite(animeId);
      await _local.remove(animeId);
    });
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Failure {
      rethrow;
    } catch (e) {
      throw Failure.fromException(e);
    }
  }
}
