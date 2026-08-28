import 'package:dio/dio.dart';

import '../../../core/error/failures.dart';
import '../../../shared/models/stream_link.dart';
import 'stream_remote_datasource.dart';
import 'witanime_webview_resolver.dart';

/// Repository for stream-link resolution.
///
/// WitAnime sits behind Cloudflare, which blocks the backend's datacenter IP.
/// For WitAnime episodes ("slug|number" ids) we resolve on-device with a
/// headless WebView (the phone's residential IP clears Cloudflare). Other ids
/// fall back to the backend datasource.
class StreamRepository {
  StreamRepository(this._remote, {WitAnimeWebViewResolver? resolver})
      : _resolver = resolver ?? WitAnimeWebViewResolver();

  final StreamRemoteDataSource _remote;
  final WitAnimeWebViewResolver _resolver;

  /// Set false once everything works, to stop showing the debug trace on the
  /// "No sources" path.
  static const bool debugTraceOnFailure = true;

  Future<List<StreamLink>> resolveStreamLinks(
    String episodeId, {
    String languageCode = 'ar',
    CancelToken? cancelToken,
  }) async {
    try {
      if (episodeId.contains('|')) {
        final parts = episodeId.split('|');
        final slug = parts[0].trim();
        final number = int.tryParse(parts.length > 1 ? parts[1].trim() : '');
        if (slug.isNotEmpty && number != null && number > 0) {
          final result = await _resolver.resolveWithTrace(
            slug: slug,
            episodeNumber: number,
          );

          if (!result.ok) {
            // Nothing playable. During bring-up, surface the trace as an error
            // so it's visible on-device. Flip debugTraceOnFailure to false to
            // go back to the clean empty state.
            if (debugTraceOnFailure) {
              throw ServerFailure('Resolve failed:\n${result.trace.join('\n')}');
            }
            return const [];
          }

          final stream = result.stream!;
          return [
            StreamLink.fromJson({
              'server': 'WitAnime',
              'url': stream.url,
              'format': stream.format,
              'quality': stream.format == 'hls' ? 'auto' : 'unknown',
              'headers': stream.headers,
            }),
          ];
        }
      }

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
