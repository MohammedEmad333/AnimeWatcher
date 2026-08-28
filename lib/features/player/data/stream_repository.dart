import 'package:dio/dio.dart';

import '../../../core/error/failures.dart';
import '../../../shared/models/stream_link.dart';
import 'stream_remote_datasource.dart';
import 'witanime_webview_resolver.dart';

/// Repository for stream-link resolution.
///
/// WitAnime sits behind Cloudflare, which blocks the backend's datacenter IP.
/// So for WitAnime episodes we resolve the stream **on-device** with a headless
/// WebView (the phone's residential IP passes Cloudflare). Ids that aren't in
/// the WitAnime `slug|number` shape fall back to the backend datasource.
class StreamRepository {
  StreamRepository(this._remote, {WitAnimeWebViewResolver? resolver})
      : _resolver = resolver ?? WitAnimeWebViewResolver();

  final StreamRemoteDataSource _remote;
  final WitAnimeWebViewResolver _resolver;

  /// Resolves every playable source for an episode, or an empty list when it
  /// has none.
  Future<List<StreamLink>> resolveStreamLinks(
    String episodeId, {
    String languageCode = 'ar',
    CancelToken? cancelToken,
  }) async {
    try {
      // WitAnime ids are "slug|number" → resolve on-device.
      if (episodeId.contains('|')) {
        final parts = episodeId.split('|');
        final slug = parts[0].trim();
        final number = int.tryParse(parts.length > 1 ? parts[1].trim() : '');
        if (slug.isNotEmpty && number != null && number > 0) {
          final stream = await _resolver.resolve(
            slug: slug,
            episodeNumber: number,
          );
          if (stream == null) return const []; // nothing playable → empty state
          return [
            StreamLink.fromJson({
              'server': 'WitAnime',
              'url': stream.url,
              'format': stream.format, // 'hls' | 'mp4'
              'quality': stream.format == 'hls' ? 'auto' : 'unknown',
              'headers': stream.headers,
            }),
          ];
        }
      }

      // Fallback: non-WitAnime ids still use the backend.
      final links = await _remote.resolveStreamLinks(
        episodeId,
        languageCode: languageCode,
        cancelToken: cancelToken,
      );
      return [
        for (final link in links)
          if (link.url.isNotEmpty) link,
      ];
    } on Failure {
      rethrow;
    } catch (e) {
      throw Failure.fromException(e);
    }
  }
}
