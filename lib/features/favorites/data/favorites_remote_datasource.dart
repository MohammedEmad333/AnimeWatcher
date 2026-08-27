import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/anime.dart';

/// Authenticated remote datasource for the user's cloud favorites.
///
/// Favorites are stored denormalized on the backend (`anime_id` + `title` +
/// `cover_image`), so [getFavorites] returns fully-rendered anime cards with no
/// extra catalog/Jikan hydration. All calls rely on the Dio auth interceptor to
/// attach the JWT; a missing/expired token surfaces as `401` → `Failure`.
class FavoritesRemoteDataSource {
  const FavoritesRemoteDataSource(this._client);

  final DioClient _client;

  Future<List<Anime>> getFavorites() async {
    final data = await _client.get(ApiConstants.favorites);
    final rows = data is Map && data['data'] != null ? data['data'] : data;
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((row) => _animeFromFavorite(row.cast<String, dynamic>()))
        .toList();
  }

  /// Adds a favorite, sending the display metadata so it can be echoed back on
  /// future reads.
  Future<void> addFavorite(Anime anime) async {
    await _client.post(
      ApiConstants.favorites,
      data: {
        'anime_id': anime.id,
        'title': anime.title,
        'cover_image': anime.coverUrl,
      },
    );
  }

  Future<void> removeFavorite(String animeId) async {
    await _client.delete(
      ApiConstants.favorites,
      data: {'anime_id': animeId},
    );
  }

  /// Maps a denormalized favorites row to an [Anime]. The backend's
  /// `anime_id` / `cover_image` map to [Anime.id] / [Anime.coverUrl].
  Anime _animeFromFavorite(Map<String, dynamic> row) {
    return Anime(
      id: (row['anime_id'] ?? '').toString(),
      title: (row['title'] ?? '') as String? ?? '',
      coverUrl: (row['cover_image'] ?? row['cover_url'] ?? '') as String? ?? '',
    );
  }
}
