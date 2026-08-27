import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';

/// Authenticated remote datasource for watch history / resume positions.
class HistoryRemoteDataSource {
  const HistoryRemoteDataSource(this._client);

  final DioClient _client;

  /// Returns the saved playback position (in seconds) for an episode, or `0`
  /// if none has been recorded yet.
  Future<int> getResume({
    required String animeId,
    required String episodeId,
  }) async {
    final data = await _client.get(
      ApiConstants.history,
      queryParameters: {'anime_id': animeId, 'episode_id': episodeId},
    );
    final payload = data is Map && data['data'] != null ? data['data'] : data;
    final seconds = payload is Map ? payload['playback_time'] : null;
    return seconds is num ? seconds.toInt() : 0;
  }

  /// UPSERTs the current playback position for an episode.
  Future<void> saveProgress({
    required String animeId,
    required String episodeId,
    required int playbackTime,
  }) async {
    await _client.post(
      ApiConstants.history,
      data: {
        'anime_id': animeId,
        'episode_id': episodeId,
        'playback_time': playbackTime,
      },
    );
  }
}
