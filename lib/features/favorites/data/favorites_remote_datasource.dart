import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/anime.dart';

/// Authenticated remote datasource for the user's cloud favorites.
///
/// All calls rely on the Dio auth interceptor to attach the JWT; a missing /
/// expired token surfaces as a `401` → [ServerException] which the repository
/// maps to a [Failure].
class FavoritesRemoteDataSource {
  const FavoritesRemoteDataSource(this._client);

  final DioClient _client;

  Future<List<Anime>> getFavorites() async {
    final data = await _client.get(ApiConstants.favorites);
    final raw = data is Map && data['data'] != null ? data['data'] : data;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Anime.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<void> addFavorite(String animeId) async {
    await _client.post(ApiConstants.favorite(animeId));
  }

  Future<void> removeFavorite(String animeId) async {
    await _client.delete(ApiConstants.favorite(animeId));
  }
}
