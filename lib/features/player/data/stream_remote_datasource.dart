import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/stream_link.dart';

/// Remote datasource that resolves a playable stream URL for an episode.
///
/// The backend performs on-the-fly scraping, which can be slow, so this call
/// uses an extended receive timeout ([ApiConstants.streamReceiveTimeout]).
class StreamRemoteDataSource {
  const StreamRemoteDataSource(this._client);

  final DioClient _client;

  /// Requests the backend to scrape and return a direct video link for
  /// [episodeId]. Optionally cancelable via [cancelToken] (e.g. when the user
  /// leaves the player before the link resolves).
  Future<StreamLink> resolveStreamLink(
    String episodeId, {
    CancelToken? cancelToken,
  }) async {
    final data = await _client.get(
      ApiConstants.streamLink(episodeId),
      options: Options(receiveTimeout: ApiConstants.streamReceiveTimeout),
      cancelToken: cancelToken,
    );
    final map = data is Map && data['data'] != null ? data['data'] : data;
    return StreamLink.fromJson((map as Map).cast<String, dynamic>());
  }
}
