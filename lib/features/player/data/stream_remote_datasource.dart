import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/stream_link.dart';

/// Remote datasource that resolves a playable stream URL for an episode.
///
/// Calls `GET /api/episodes/sources?episode_id=..&lang=..`, whose backend
/// ScraperService performs on-the-fly scraping (which can be slow), so this
/// call uses an extended receive timeout ([ApiConstants.streamReceiveTimeout]).
/// The endpoint returns a preference-ordered `sources` list; we pick the first
/// playable one and surface it as a [StreamLink].
class StreamRemoteDataSource {
  const StreamRemoteDataSource(this._client);

  final DioClient _client;

  /// Requests the backend to scrape and return a direct video link for
  /// [episodeId] in [languageCode] (`ar` / `en`). Optionally cancelable via
  /// [cancelToken] (e.g. when the user leaves the player before it resolves).
  ///
  /// Returns `null` when the endpoint responds successfully but the episode has
  /// **no playable sources** — a normal, expected outcome the player renders as
  /// a clean "No streaming sources available" state rather than an error. Real
  /// failures (network/timeout/5xx) still throw the app's typed exceptions.
  Future<StreamLink?> resolveStreamLink(
    String episodeId, {
    String languageCode = 'ar',
    CancelToken? cancelToken,
  }) async {
    final data = await _client.get(
      ApiConstants.episodeSources,
      queryParameters: {'episode_id': episodeId, 'lang': languageCode},
      options: Options(receiveTimeout: ApiConstants.streamReceiveTimeout),
      cancelToken: cancelToken,
    );

    // Tolerate the `{ "data": ... }` envelope as well as a bare payload.
    final payload = data is Map && data['data'] != null ? data['data'] : data;

    final sources = payload is Map ? payload['sources'] : payload;
    if (sources is! List || sources.isEmpty) {
      return null; // resolved fine, just nothing to play
    }

    final first = sources.firstWhere(
      (s) => s is Map && (s['url']?.toString().isNotEmpty ?? false),
      orElse: () => null,
    );
    if (first is! Map) {
      return null; // every entry was blank/urless → treat as no sources
    }

    return StreamLink.fromJson(first.cast<String, dynamic>());
  }
}
