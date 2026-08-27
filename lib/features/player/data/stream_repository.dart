import 'package:dio/dio.dart';

import '../../../core/error/failures.dart';
import '../../../shared/models/stream_link.dart';
import 'stream_remote_datasource.dart';

/// Repository for stream-link resolution.
class StreamRepository {
  const StreamRepository(this._remote);

  final StreamRemoteDataSource _remote;

  /// Resolves every playable source for an episode, or an empty list when it
  /// has none.
  ///
  /// Genuine failures are rethrown as typed [Failure]s; a successful resolve
  /// that yields no (or only blank) sources returns an empty list so the player
  /// can show a dedicated "No streaming sources available" state. The order
  /// follows the backend's server preference, so `sources.first` is the default
  /// pick and the full list feeds the server/quality picker.
  Future<List<StreamLink>> resolveStreamLinks(
    String episodeId, {
    String languageCode = 'ar',
    CancelToken? cancelToken,
  }) async {
    try {
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
