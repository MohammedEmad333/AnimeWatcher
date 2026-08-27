import '../../../core/error/failures.dart';
import 'history_remote_datasource.dart';

/// Repository for watch-history sync. Read errors are translated to [Failure];
/// progress writes are best-effort (see the player, which ignores sync errors
/// so a flaky network never interrupts playback).
class HistoryRepository {
  const HistoryRepository(this._remote);

  final HistoryRemoteDataSource _remote;

  Future<int> getResume({
    required String animeId,
    required String episodeId,
  }) async {
    try {
      return await _remote.getResume(animeId: animeId, episodeId: episodeId);
    } on Failure {
      rethrow;
    } catch (e) {
      throw Failure.fromException(e);
    }
  }

  Future<void> saveProgress({
    required String animeId,
    required String episodeId,
    required int playbackTime,
  }) async {
    try {
      await _remote.saveProgress(
        animeId: animeId,
        episodeId: episodeId,
        playbackTime: playbackTime,
      );
    } on Failure {
      rethrow;
    } catch (e) {
      throw Failure.fromException(e);
    }
  }
}
