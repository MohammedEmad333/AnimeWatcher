import 'dart:async';

import 'package:better_player/better_player.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failures.dart';
import '../../../core/providers/core_providers.dart';
import '../../../shared/models/episode.dart';
import '../../../shared/models/stream_link.dart';
import '../../auth/providers/auth_providers.dart';
import '../../catalog/providers/catalog_providers.dart';
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

/// How many times a mid-playback failure (an expired/temporary scraped link)
/// triggers an automatic re-scrape before we surface the error to the user.
/// The budget is refilled once playback actually makes progress, so a link that
/// plays for a while and then dies gets a fresh set of attempts.
const int _maxAutoRescrapes = 2;

/// Small delay before an automatic re-scrape, so a flapping source isn't hit in
/// a tight loop.
const Duration _rescrapeBackoff = Duration(milliseconds: 1200);

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
    required String languageCode,
  })  : _streamRepository = streamRepository,
        _historyRepository = historyRepository,
        _syncEnabled = syncEnabled,
        _languageCode = languageCode,
        super(const PlayerLoading()) {
    load();
  }

  final StreamRepository _streamRepository;
  final HistoryRepository _historyRepository;
  final Episode episode;

  /// Whether resume/sync is active (only when the user is signed in).
  final bool _syncEnabled;

  /// Content language (`ar` / `en`) sent to the source-resolution endpoint.
  final String _languageCode;

  BetterPlayerController? _controller;
  CancelToken? _cancelToken;
  Timer? _syncTimer;
  int _resumeSeconds = 0;
  bool _hasSeeked = false;
  bool _disposed = false;

  /// Every source resolved for the current episode, in backend-preference
  /// order, plus the one currently attached to the controller. These drive the
  /// server/quality picker and let a user switch servers mid-playback.
  List<StreamLink> _sources = const [];
  StreamLink? _selected;

  /// Auto re-scrape bookkeeping for expired/temporary links.
  int _autoRescrapes = 0;
  bool _recovering = false;

  /// Resolves the link, restores the resume position, and prepares playback.
  /// Safe to call repeatedly (Retry).
  Future<void> load() async {
    _teardownPlayback();
    _recovering = false; // a new load cycle supersedes any in-flight recovery
    _cancelToken = CancelToken();
    _hasSeeked = false;
    if (!_disposed) state = const PlayerLoading();

    try {
      final links = await _streamRepository.resolveStreamLinks(
        episode.id,
        languageCode: _languageCode,
        cancelToken: _cancelToken,
      );
      if (_disposed) return;

      // Resolved successfully but nothing is playable → dedicated empty state
      // (with Retry), kept distinct from the red error state below.
      if (links.isEmpty) {
        _sources = const [];
        _selected = null;
        state = const PlayerNoSources();
        return;
      }

      _sources = links;
      // Keep the user's chosen server across re-resolves (Retry / auto
      // re-scrape) when it's still offered; otherwise fall back to the
      // preferred (first) source.
      _selected = _pickSource(links, _selected);

      // Best-effort resume lookup; never blocks playback on failure.
      _resumeSeconds = await _fetchResume();
      if (_disposed) return;

      final controller = _buildController(_selected!);
      _controller = controller;
      controller.addEventsListener(_onPlayerEvent);

      state = PlayerReady(
        controller: controller,
        sources: _sources,
        selected: _selected!,
      );
    } on Failure catch (failure) {
      if (!_disposed) state = PlayerError(failure);
    } catch (e) {
      if (!_disposed) state = PlayerError(Failure.fromException(e));
    }
  }

  /// User-initiated retry: refill the auto re-scrape budget and reload.
  Future<void> retry() {
    _autoRescrapes = 0;
    return load();
  }

  /// Switches playback to a different already-resolved [link] (e.g. the user
  /// picked another server/quality). Resumes at the current playback position
  /// so switching servers doesn't lose the user's place, and no re-scrape is
  /// needed since every source was resolved up front.
  ///
  /// A no-op when [link] is already selected or isn't one of the resolved
  /// sources.
  void selectSource(StreamLink link) {
    if (_disposed) return;
    if (_selected != null && _selected!.url == link.url) return;
    if (!_sources.contains(link)) return;

    // Carry the current position over to the new server.
    final position = _controller?.videoPlayerController?.value.position;
    _resumeSeconds = position?.inSeconds ?? 0;
    _hasSeeked = false;
    // A deliberate switch is a fresh, working start — refill the re-scrape
    // budget so an expiry on the new server gets its own attempts.
    _autoRescrapes = 0;
    _selected = link;

    // Dispose only the current controller; keep the resolved source list and
    // the in-flight resume position. better_player shows its own buffering
    // placeholder, so no PlayerLoading flash is needed for a local swap.
    _syncTimer?.cancel();
    _syncTimer = null;
    _controller?.removeEventsListener(_onPlayerEvent);
    _controller?.dispose();

    final controller = _buildController(link);
    _controller = controller;
    controller.addEventsListener(_onPlayerEvent);

    state = PlayerReady(
      controller: controller,
      sources: _sources,
      selected: link,
    );
  }

  /// Picks which source to attach after a resolve: prefer the user's previously
  /// [current] selection (matched by url, else by server label) when it's still
  /// available, otherwise the backend's first/preferred source.
  StreamLink _pickSource(List<StreamLink> links, StreamLink? current) {
    if (current == null) return links.first;
    return links.firstWhere(
      (l) => l.url == current.url,
      orElse: () => links.firstWhere(
        (l) => l.server == current.server,
        orElse: () => links.first,
      ),
    );
  }

  /// Handles a mid-playback failure (typically an expired/temporary scraped
  /// link). Automatically re-resolves a fresh link up to [_maxAutoRescrapes]
  /// times before surfacing [PlayerError]. Re-entrant calls (the player can emit
  /// several exception events in a row) are collapsed via [_recovering].
  Future<void> _recoverFromPlaybackFailure() async {
    if (_disposed || _recovering) return;

    if (_autoRescrapes >= _maxAutoRescrapes) {
      state = const PlayerError(
        ServerFailure('Playback failed. The link may have expired.'),
      );
      return;
    }

    _recovering = true;
    _autoRescrapes++;
    // Detach the listener so the dead controller can't emit further exceptions
    // while we back off (full teardown/dispose happens in load(), off the event
    // callback stack). Surface the loading state immediately.
    _controller?.removeEventsListener(_onPlayerEvent);
    state = const PlayerLoading();

    await Future<void>.delayed(_rescrapeBackoff);
    if (_disposed) return;

    // load() clears _recovering and re-resolves a fresh link from the backend.
    await load();
  }

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
      case BetterPlayerEventType.progress:
        // Real playback progress means this link works — refill the auto
        // re-scrape budget so a later expiry gets a fresh set of attempts.
        _autoRescrapes = 0;
        break;
      case BetterPlayerEventType.exception:
        // An expired/temporary scraped link: try to recover with a fresh scrape
        // before showing the error.
        unawaited(_recoverFromPlaybackFailure());
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
    languageCode: ref.watch(selectedLanguageProvider).code,
  ),
);
