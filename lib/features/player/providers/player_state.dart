import 'package:better_player/better_player.dart';

import '../../../core/error/failures.dart';
import '../../../shared/models/stream_link.dart';

/// UI state for the Video Player screen.
///
/// Modeled as a sealed class so the screen can exhaustively render the three
/// phases of playback setup: resolving the link, ready to play, or failed
/// (with a Retry affordance).
sealed class PlayerState {
  const PlayerState();
}

/// The backend is scraping / the link is being resolved and the player is
/// being prepared. Shows a loading indicator.
class PlayerLoading extends PlayerState {
  const PlayerLoading();
}

/// Shared base for the "playing" states ([PlayerReady] for direct media,
/// [PlayerEmbed] for iframe/web embeds). Carries the full list of resolved
/// [sources] and the currently [selected] one so the screen can render a
/// server/quality picker and let the user switch between servers mid-playback,
/// regardless of how the current source is being played.
sealed class PlayerReadyState extends PlayerState {
  const PlayerReadyState({required this.sources, required this.selected});

  /// Every source the backend resolved, in preference order.
  final List<StreamLink> sources;

  /// The source currently being played.
  final StreamLink selected;

  /// Whether there's more than one source to choose between (drives whether the
  /// picker affordance is shown at all).
  bool get hasChoice => sources.length > 1;
}

/// Direct media (mp4 / HLS) is ready and attached to a native [controller].
class PlayerReady extends PlayerReadyState {
  const PlayerReady({
    required this.controller,
    required super.sources,
    required super.selected,
  });

  final BetterPlayerController controller;
}

/// The selected source is an iframe/web embed with no direct media URL, so it's
/// played in a WebView rather than the native player.
///
/// Embeds expose no playback position, so resume/sync is unavailable for this
/// state — a deliberate limitation kept out of the sync path in the controller.
class PlayerEmbed extends PlayerReadyState {
  const PlayerEmbed({
    required this.url,
    required this.headers,
    required super.sources,
    required super.selected,
  });

  /// The embed page URL to load in the WebView.
  final String url;

  /// Headers to send with the initial WebView request (e.g. Referer) so the
  /// embed host accepts it.
  final Map<String, String> headers;
}

/// The resolve succeeded but the episode has no playable sources right now.
///
/// This is a normal, expected outcome (not a failure) — the UI shows a clean
/// "No streaming sources available" message with a Retry, distinct from the
/// red error state used for genuine network/playback failures.
class PlayerNoSources extends PlayerState {
  const PlayerNoSources();
}

/// Something failed — either resolving the link or initializing playback.
/// Carries the [Failure] to show and enables the Retry button.
class PlayerError extends PlayerState {
  const PlayerError(this.failure);

  final Failure failure;
}
