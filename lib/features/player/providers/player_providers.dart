import 'package:better_player/better_player.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failures.dart';
import '../../../core/providers/core_providers.dart';
import '../../../shared/models/stream_link.dart';
import '../data/stream_remote_datasource.dart';
import '../data/stream_repository.dart';
import 'player_state.dart';

final _streamDataSourceProvider = Provider<StreamRemoteDataSource>(
  (ref) => StreamRemoteDataSource(ref.watch(dioClientProvider)),
);

final streamRepositoryProvider = Provider<StreamRepository>(
  (ref) => StreamRepository(ref.watch(_streamDataSourceProvider)),
);

/// Drives the Video Player screen for a single episode.
///
/// Lifecycle:
///  1. Emits [PlayerLoading] and asks the backend to resolve a direct link.
///  2. Builds a [BetterPlayerController] for the returned MP4 / HLS URL and
///     emits [PlayerReady].
///  3. On any failure (resolution or playback), emits [PlayerError] so the UI
///     can show a message + Retry button. [retry] re-runs the whole flow.
///
/// Created per-episode via [playerControllerProvider] (a `family`) and disposes
/// the underlying [BetterPlayerController] + cancels any in-flight request when
/// the screen is torn down.
class PlayerController extends StateNotifier<PlayerState> {
  PlayerController(this._repository, this.episodeId)
      : super(const PlayerLoading()) {
    load();
  }

  final StreamRepository _repository;
  final String episodeId;

  BetterPlayerController? _controller;
  CancelToken? _cancelToken;
  bool _disposed = false;

  /// Resolves the link and prepares playback. Safe to call repeatedly (Retry).
  Future<void> load() async {
    // Tear down any previous attempt before starting a new one.
    _disposeController();
    _cancelToken = CancelToken();
    if (!_disposed) state = const PlayerLoading();

    try {
      final link = await _repository.resolveStreamLink(
        episodeId,
        cancelToken: _cancelToken,
      );
      if (_disposed) return;

      final controller = _buildController(link);
      _controller = controller;

      // Surface late playback errors (e.g. CDN drops the stream mid-load) as a
      // retryable PlayerError instead of a silent black screen.
      controller.addEventsListener(_onPlayerEvent);

      state = PlayerReady(controller);
    } on Failure catch (failure) {
      if (!_disposed) state = PlayerError(failure);
    } catch (e) {
      if (!_disposed) state = PlayerError(Failure.fromException(e));
    }
  }

  /// Re-attempts the entire resolve → play flow.
  Future<void> retry() => load();

  BetterPlayerController _buildController(StreamLink link) {
    final dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      link.url,
      // HLS needs liveStream=false + the m3u8 mime for correct handling.
      videoFormat: link.format == StreamFormat.hls
          ? BetterPlayerVideoFormat.hls
          : BetterPlayerVideoFormat.other,
      // Forward any CDN-required headers (Referer, User-Agent, …).
      headers: link.headers,
      cacheConfiguration: const BetterPlayerCacheConfiguration(
        useCache: false, // scraped links are short-lived; don't cache them
      ),
      notificationConfiguration: const BetterPlayerNotificationConfiguration(
        showNotification: false,
      ),
    );

    return BetterPlayerController(
      const BetterPlayerConfiguration(
        aspectRatio: 16 / 9,
        fit: BoxFit.contain,
        autoPlay: true,
        handleLifecycle: true,
        // We render our own loading/error UI, so suppress the default ones.
        showPlaceholderUntilPlay: true,
        errorBuilder: _hiddenErrorBuilder,
        controlsConfiguration: BetterPlayerControlsConfiguration(
          enableSkips: true,
          enablePlaybackSpeed: true,
          enableFullscreen: true,
        ),
      ),
      betterPlayerDataSource: dataSource,
    );
  }

  void _onPlayerEvent(BetterPlayerEvent event) {
    if (event.betterPlayerEventType == BetterPlayerEventType.exception) {
      if (!_disposed) {
        state = const PlayerError(
          ServerFailure('Playback failed. The link may have expired.'),
        );
      }
    }
  }

  void _disposeController() {
    _cancelToken?.cancel('New load requested.');
    _cancelToken = null;
    _controller?.removeEventsListener(_onPlayerEvent);
    _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _disposeController();
    super.dispose();
  }
}

/// Returning an empty widget hands error rendering entirely to our own UI.
Widget _hiddenErrorBuilder(_, __) => const SizedBox.shrink();

/// One [PlayerController] per episode id.
final playerControllerProvider = StateNotifierProvider.autoDispose
    .family<PlayerController, PlayerState, String>(
  (ref, episodeId) =>
      PlayerController(ref.watch(streamRepositoryProvider), episodeId),
);
