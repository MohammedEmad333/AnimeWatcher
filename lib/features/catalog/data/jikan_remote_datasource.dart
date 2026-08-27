import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/error/exceptions.dart';
import '../../../core/network/api_interceptors.dart';
import '../../../shared/models/anime.dart';
import '../../../shared/models/episode.dart';

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

  /// Recently aired episodes across all series
  /// (`GET /watch/episodes`).
  ///
  /// Jikan groups the payload by title: each item carries an `entry` (the
  /// anime) plus its most recent `episodes`. We flatten that into a single,
  /// ordered list of [Episode]s for the Home "Latest Episodes" feed, tagging
  /// each with its series title (shown as the tile subtitle) and cover.
  Future<List<Episode>> getLatestEpisodes({int limit = 20}) async {
    try {
      final response = await _dio.get<dynamic>(
        ApiConstants.jikanWatchEpisodes,
      );
      final data = response.data;
      final items = data is Map ? data['data'] : null;
      if (items is! List) return const [];

      final episodes = <Episode>[];
      for (final entryRaw in items.whereType<Map>()) {
        final entry = entryRaw.cast<String, dynamic>();
        final anime = (entry['entry'] as Map?)?.cast<String, dynamic>();
        if (anime == null) continue;

        final animeId = (anime['mal_id'] ?? '').toString();
        final animeTitle =
            (anime['title'] ?? anime['title_english'] ?? '').toString();
        final jpg = (anime['images'] as Map?)?['jpg'] as Map?;
        final thumb =
            (jpg?['image_url'] ?? jpg?['large_image_url'] ?? '').toString();

        final epList = (entry['episodes'] as List?) ?? const [];
        for (final epRaw in epList.whereType<Map>()) {
          final ep = epRaw.cast<String, dynamic>();
          final epMalId = (ep['mal_id'] ?? '').toString();
          final number = ep['mal_id'] is num
              ? (ep['mal_id'] as num).toInt()
              : int.tryParse(epMalId) ?? 0;

          episodes.add(
            Episode.fromJson({
              // Compose a stable, unique key so Riverpod/ListView can
              // distinguish rows even when two series share an episode number.
              'id': '${animeId}_$epMalId',
              'anime_id': animeId,
              'number': number,
              // The tile renders "Episode {number}" as its title and this as
              // the subtitle, so surfacing the series name here is most useful.
              'title': animeTitle,
              'thumbnail_url': thumb,
            }),
          );
          if (episodes.length >= limit) return episodes;
        }
      }
      return episodes;
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// Anime genres / categories (`GET /genres/anime`), returned as a plain list
  /// of names for the Home "Categories" chips.
  Future<List<String>> getCategories() async {
    try {
      final response = await _dio.get<dynamic>(ApiConstants.jikanGenres);
      final data = response.data;
      final items = data is Map ? data['data'] : null;
      if (items is! List) return const [];
      return items
          .whereType<Map>()
          .map((g) => (g['name'] ?? '').toString())
          .where((name) => name.isNotEmpty)
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
