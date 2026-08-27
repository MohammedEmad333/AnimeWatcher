import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/anime.dart';
import '../../../shared/models/episode.dart';

/// Remote datasource for the anime catalog (home feeds + details).
///
/// Talks to the backend via [DioClient] and maps raw JSON into domain models.
/// It only throws the app's typed exceptions (surfaced by the Dio error
/// interceptor); repositories translate those into `Failure`s.
class CatalogRemoteDataSource {
  const CatalogRemoteDataSource(this._client);

  final DioClient _client;

  Future<List<Episode>> getLatestEpisodes() async {
    final data = await _client.get(ApiConstants.latestEpisodes);
    return _asList(data).map(Episode.fromJson).toList();
  }

  Future<List<Anime>> getTrending() async {
    final data = await _client.get(ApiConstants.trending);
    return _asList(data).map(Anime.fromJson).toList();
  }

  Future<List<String>> getCategories() async {
    final data = await _client.get(ApiConstants.categories);
    return _asList(data)
        .map((e) => (e['name'] ?? e['title'] ?? e.toString()).toString())
        .toList();
  }

  Future<Anime> getAnimeDetails(String animeId) async {
    final data = await _client.get(ApiConstants.animeDetails(animeId));
    return Anime.fromJson(_asMap(data));
  }

  Future<List<Episode>> getEpisodes(String animeId) async {
    final data = await _client.get(ApiConstants.animeEpisodes(animeId));
    return _asList(data).map(Episode.fromJson).toList();
  }

  // --- Response-shape helpers -----------------------------------------------
  // Backends often wrap payloads in `{ "data": [...] }`; tolerate both shapes.
  List<Map<String, dynamic>> _asList(dynamic data) {
    final raw = data is Map && data['data'] != null ? data['data'] : data;
    if (raw is List) {
      return raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    return const [];
  }

  Map<String, dynamic> _asMap(dynamic data) {
    final raw = data is Map && data['data'] != null ? data['data'] : data;
    return raw is Map ? raw.cast<String, dynamic>() : <String, dynamic>{};
  }
}
