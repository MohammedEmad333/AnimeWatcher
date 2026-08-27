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

/// A playable controller is ready and attached.
///
/// Carries the full list of resolved [sources] and the currently [selected]
/// one so the screen can render a server/quality picker and let the user switch
/// between servers mid-playback.
class PlayerReady extends PlayerState {
  const PlayerReady({
    required this.controller,
    required this.sources,
    required this.selected,
  });

  final BetterPlayerController controller;

  /// Every source the backend resolved, in preference order.
  final List<StreamLink> sources;

  /// The source currently attached to [controller].
  final StreamLink selected;

  /// Whether there's more than one source to choose between (drives whether the
  /// picker affordance is shown at all).
  bool get hasChoice => sources.length > 1;
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
