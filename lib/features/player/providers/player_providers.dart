import 'dart:async';

import 'package:better_player/better_player.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failures.dart';
import '../../../core/providers/core_providers.dart';
import '../../../shared/models/episode.dart';
import '../../../shared/models/stream_link.dart';
import '../../auth/providers/auth_providers.dart';
import '../../history/data/history_repository.dart';
import '../../history/providers/history_providers.dart';
import '../data/stream_remote_datasource.dart';
import '../data/stream_repository.dart';
import 'player_state.dart';

final _streamDataSourceProvider = Provider<StreamRemoteDataSource>(
  (ref) => StreamRemoteDataSource(ref.watch(dioClientProvider)),
);

final streamRepositoryProvider = Provider<StreamRepository>(
  (ref) => StreamRepository(ref.watch(_streamDataSourceProvider)),
);

/// How often the current playback position is synced to the backend.
const Duration _syncInterval = Duration(seconds: 10);

/// Drives the Video Player screen for a single [Episode].
///
/// Lifecycle:
///  1. Emits [PlayerLoading] and asks the backend to resolve a direct link.
///  2. When authenticated, fetches the saved resume position for this episode.
///  3. Builds a [BetterPlayerController], seeks to the resume position once the
///     video is initialized, and emits [PlayerReady].
///  4. While playing, syncs the position to the backend every
///     [_syncInterval]; also syncs a final time on dispose.
///  5. On any failure, emits [PlayerError] so the UI can show Retry.
///
/// [retry] re-runs the whole flow.
class PlayerController extends StateNotifier<PlayerState> {
  PlayerController({
    required StreamRepository streamRepository,
    required HistoryRepository historyRepository,
    required this.episode,
    required bool syncEnabled,
  })  : _streamRepository = streamRepository,
        _historyRepository = historyRepository,
        _syncEnabled = syncEnabled,
        super(const PlayerLoading()) {
    load();
  }

  final StreamRepository _streamRepository;
  final HistoryRepository _historyRepository;
  final Episode episode;

  /// Whether resume/sync is active (only when the user is signed in).
  final bool _syncEnabled;

  BetterPlayerController? _controller;
  CancelToken? _cancelToken;
  Timer? _syncTimer;
  int _resumeSeconds = 0;
  bool _hasSeeked = false;
  bool _disposed = false;

  /// Resolves the link, restores the resume position, and prepares playback.
  /// Safe to call repeatedly (Retry).
  Future<void> load() async {
    _teardownPlayback();
    _cancelToken = CancelToken();
    _hasSeeked = false;
    if (!_disposed) state = const PlayerLoading();

    try {
      final link = await _streamRepository.resolveStreamLink(
        episode.id,
        cancelToken: _cancelToken,
      );
      if (_disposed) return;

      // Best-effort resume lookup; never blocks playback on failure.
      _resumeSeconds = await _fetchResume();
      if (_disposed) return;

      final controller = _buildController(link);
      _controller = controller;
      controller.addEventsListener(_onPlayerEvent);

      state = PlayerReady(controller);
    } on Failure catch (failure) {
      if (!_disposed) state = PlayerError(failure);
    } catch (e) {
      if (!_disposed) state = PlayerError(Failure.fromException(e));
    }
  }

  Future<void> retry() => load();

  Future<int> _fetchResume() async {
    if (!_syncEnabled) return 0;
    try {
      return await _historyRepository.getResume(
        animeId: episode.animeId,
        episodeId: episode.id,
      );
    } catch (_) {
      return 0; // resume is a convenience, not a hard requirement
    }
  }

  BetterPlayerController _buildController(StreamLink link) {
    final dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      link.url,
      videoFormat: link.format == StreamFormat.hls
          ? BetterPlayerVideoFormat.hls
          : BetterPlayerVideoFormat.other,
      headers: link.headers,
      cacheConfiguration: const BetterPlayerCacheConfiguration(useCache: false),
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
    switch (event.betterPlayerEventType) {
      case BetterPlayerEventType.initialized:
        _seekToResumeOnce();
        _startSyncTimer();
        break;
      case BetterPlayerEventType.exception:
        if (!_disposed) {
          state = const PlayerError(
            ServerFailure('Playback failed. The link may have expired.'),
          );
        }
        break;
      default:
        break;
    }
  }

  /// Seeks to the saved resume position exactly once, after initialization.
  void _seekToResumeOnce() {
    if (_hasSeeked || _resumeSeconds <= 0) return;
    _hasSeeked = true;
    _controller?.seekTo(Duration(seconds: _resumeSeconds));
  }

  void _startSyncTimer() {
    if (!_syncEnabled) return;
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) => _syncProgress());
  }

  /// Sends the current position to the backend (fire-and-forget).
  void _syncProgress() {
    if (!_syncEnabled) return;
    final position = _controller?.videoPlayerController?.value.position;
    final seconds = position?.inSeconds ?? 0;
    if (seconds <= 0) return;
    unawaited(
      _historyRepository
          .saveProgress(
            animeId: episode.animeId,
            episodeId: episode.id,
            playbackTime: seconds,
          )
          .catchError((_) {}), // best-effort; ignore sync errors
    );
  }

  /// Cancels timers, syncs a final position, and disposes the controller.
  void _teardownPlayback({bool syncFinal = false}) {
    _syncTimer?.cancel();
    _syncTimer = null;
    if (syncFinal) _syncProgress();

    _cancelToken?.cancel('New load requested.');
    _cancelToken = null;
    _controller?.removeEventsListener(_onPlayerEvent);
    _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    _disposed = true;
    // Persist where the user stopped watching before tearing everything down.
    _teardownPlayback(syncFinal: true);
    super.dispose();
  }
}

/// Returning an empty widget hands error rendering entirely to our own UI.
Widget _hiddenErrorBuilder(_, __) => const SizedBox.shrink();

/// One [PlayerController] per episode. Keyed by [Episode] so the controller has
/// both the anime id and episode id needed for resume/sync.
final playerControllerProvider = StateNotifierProvider.autoDispose
    .family<PlayerController, PlayerState, Episode>(
  (ref, episode) => PlayerController(
    streamRepository: ref.watch(streamRepositoryProvider),
    historyRepository: ref.watch(historyRepositoryProvider),
    episode: episode,
    syncEnabled: ref.watch(isAuthenticatedProvider),
  ),
);
