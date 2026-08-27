import 'package:better_player/better_player.dart';

import '../../../core/error/failures.dart';

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
class PlayerReady extends PlayerState {
  const PlayerReady(this.controller);

  final BetterPlayerController controller;
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
