import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/error/exceptions.dart';
import '../../../core/network/api_interceptors.dart';
import '../../../shared/models/anime.dart';

/// Talks to the public Jikan API (MyAnimeList) **directly** from the app.
///
/// Why not through our backend? Some free hosts (e.g. InfinityFree) block
/// outbound cURL, so the backend's catalog proxy can't reach Jikan there. Jikan
/// is public and needs no key, so the Trending and Details screens call it
/// straight from the client and stay working regardless of where the backend
/// is hosted. Everything else (auth, favorites, history) still goes through our
/// backend via [DioClient].
///
/// This uses its **own** [Dio] instance — a different base URL and, crucially,
/// no auth interceptor, so our JWT is never sent to a third-party API. It reuses
/// [ErrorInterceptor] so failures surface as the app's typed exceptions, and
/// maps Jikan's nested JSON into the flat [Anime] model.
class JikanRemoteDataSource {
  JikanRemoteDataSource({Dio? dio}) : _dio = dio ?? _defaultDio();

  final Dio _dio;

  static Dio _defaultDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.jikanBaseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        responseType: ResponseType.json,
        headers: const {'Accept': 'application/json'},
      ),
    );
    // No AuthInterceptor here — never leak the backend JWT to Jikan.
    dio.interceptors.addAll([ErrorInterceptor(), LoggingInterceptor()]);
    return dio;
  }

  /// Popular titles for the home screen (`GET /top/anime?filter=bypopularity`).
  Future<List<Anime>> getTrending({int limit = 20}) async {
    try {
      final response = await _dio.get<dynamic>(
        ApiConstants.jikanTopAnime,
        queryParameters: {
          'filter': 'bypopularity',
          'limit': limit.clamp(1, 25),
        },
      );
      final data = response.data;
      final items = data is Map ? data['data'] : null;
      if (items is! List) return const [];
      return items
          .whereType<Map>()
          .map((e) => _mapAnime(e.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// Full details for one title (`GET /anime/{id}/full`).
  Future<Anime> getAnimeDetails(String id) async {
    try {
      final response = await _dio.get<dynamic>(ApiConstants.jikanAnimeFull(id));
      final data = response.data;
      final obj = data is Map ? data['data'] : null;
      if (obj is! Map) {
        throw const ServerException('Anime not found.', statusCode: 404);
      }
      return _mapAnime(obj.cast<String, dynamic>());
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  // --- Mapping: Jikan (nested) → Anime (flat) --------------------------------
  // Mirrors the backend JikanClient::mapAnime so both paths yield identical
  // Anime objects.
  Anime _mapAnime(Map<String, dynamic> a) {
    final jpg = (a['images'] as Map?)?['jpg'] as Map?;
    final cover = (jpg?['large_image_url'] ?? jpg?['image_url'] ?? '').toString();

    final genres = (a['genres'] as List?)
            ?.whereType<Map>()
            .map((g) => (g['name'] ?? '').toString())
            .where((s) => s.isNotEmpty)
            .toList() ??
        const <String>[];

    return Anime.fromJson({
      'id': (a['mal_id'] ?? '').toString(),
      'title': a['title_english'] ?? a['title'] ?? '',
      'cover_url': cover,
      'synopsis': a['synopsis'] ?? '',
      'rating': a['score'] ?? 0,
      'genres': genres,
      'episode_count': a['episodes'] ?? 0,
    });
  }

  /// Extracts the typed exception attached by [ErrorInterceptor]; falls back to
  /// a generic [ServerException] if none is present.
  Exception _unwrap(DioException e) {
    final error = e.error;
    if (error is Exception) return error;
    return ServerException(e.message ?? 'Unexpected error.');
  }
}
