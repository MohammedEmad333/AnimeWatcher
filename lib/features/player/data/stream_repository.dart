import 'package:dio/dio.dart';

import '../../../core/error/failures.dart';
import '../../../shared/models/stream_link.dart';
import 'stream_remote_datasource.dart';

/// Repository for stream-link resolution.
class StreamRepository {
  const StreamRepository(this._remote);

  final StreamRemoteDataSource _remote;

  Future<StreamLink> resolveStreamLink(
    String episodeId, {
    String languageCode = 'ar',
    CancelToken? cancelToken,
  }) async {
    try {
      final link = await _remote.resolveStreamLink(
        episodeId,
        languageCode: languageCode,
        cancelToken: cancelToken,
      );
      if (link.url.isEmpty) {
        throw const ServerFailure('The stream link could not be resolved.');
      }
      return link;
    } on Failure {
      rethrow;
    } catch (e) {
      throw Failure.fromException(e);
    }
  }
}
