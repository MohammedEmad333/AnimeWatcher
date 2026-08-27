import 'package:better_player/better_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/error/failures.dart';
import '../../../shared/models/episode.dart';
import '../../../shared/models/stream_link.dart';
import '../providers/player_providers.dart';
import '../providers/player_state.dart';

/// Full-screen video player for a single [Episode].
///
/// Because the playable link is scraped on demand and can be unstable, the
/// screen renders three explicit states:
///  * **Loading** — while the backend resolves the direct link and the player
///    prepares (a spinner with a helpful caption).
///  * **Ready** — the [BetterPlayerController] plays the MP4 / HLS stream.
///  * **Error** — a friendly message plus a prominent **Retry** button that
///    re-runs the entire resolve-and-play flow.
class VideoPlayerScreen extends ConsumerWidget {
  const VideoPlayerScreen({super.key, required this.episode});

  final Episode episode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerControllerProvider(episode));
    final controller = ref.read(playerControllerProvider(episode).notifier);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'E${episode.number} · ${episode.title}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Server/quality picker — only when more than one source resolved.
          if (state is PlayerReadyState && (state as PlayerReadyState).hasChoice)
            IconButton(
              icon: const Icon(Icons.playlist_play),
              tooltip: 'Servers',
              onPressed: () => _showSourcePicker(
                context,
                state as PlayerReadyState,
                controller.selectSource,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: switch (state) {
              PlayerLoading() => const _PlayerLoadingView(),
              PlayerReady(:final controller) =>
                BetterPlayer(controller: controller),
              PlayerEmbed(:final url, :final headers) =>
                _EmbedPlayerView(url: url, headers: headers),
              PlayerNoSources() => _NoSourcesView(onRetry: controller.retry),
              PlayerError(:final failure) => _PlayerErrorView(
                  failure: failure,
                  onRetry: controller.retry,
                ),
            },
          ),
        ),
      ),
    );
  }
}

/// Opens a bottom sheet listing every resolved source so the user can switch
/// servers/qualities. Tapping a row selects it (via [onSelect]) and closes the
/// sheet; the currently playing source is marked with a check.
Future<void> _showSourcePicker(
  BuildContext context,
  PlayerReadyState state,
  void Function(StreamLink) onSelect,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF121212),
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Servers',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: state.sources.length,
                itemBuilder: (context, index) {
                  final source = state.sources[index];
                  final isSelected = source.url == state.selected.url;
                  return ListTile(
                    leading: Icon(
                      isSelected
                          ? Icons.play_circle
                          : Icons.play_circle_outline,
                      color: isSelected ? Colors.tealAccent : Colors.white54,
                    ),
                    title: Text(
                      source.server,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      source.quality,
                      style: const TextStyle(color: Colors.white54),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: Colors.tealAccent)
                        : null,
                    onTap: () {
                      Navigator.of(context).pop();
                      onSelect(source);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Plays an iframe/web-embed source in a WebView.
///
/// Used for [PlayerEmbed] sources that have no direct `.mp4`/`.m3u8` URL the
/// native player can consume. The embed page is loaded as a top-level document
/// (not nested in an iframe), forwarding any [headers] (e.g. Referer) the host
/// requires. JavaScript is enabled because embed players need it to run.
class _EmbedPlayerView extends StatefulWidget {
  const _EmbedPlayerView({required this.url, required this.headers});

  final String url;
  final Map<String, String> headers;

  @override
  State<_EmbedPlayerView> createState() => _EmbedPlayerViewState();
}

class _EmbedPlayerViewState extends State<_EmbedPlayerView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..loadRequest(Uri.parse(widget.url), headers: widget.headers);
  }

  @override
  void didUpdateWidget(covariant _EmbedPlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Switching to another embed server reuses this State — reload on URL change.
    if (oldWidget.url != widget.url) {
      _controller.loadRequest(Uri.parse(widget.url), headers: widget.headers);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: WebViewWidget(controller: _controller),
    );
  }
}

/// Loading placeholder shown while the direct link is being scraped/resolved.
class _PlayerLoadingView extends StatelessWidget {
  const _PlayerLoadingView();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: _CenteredScrollable(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(strokeWidth: 3),
          SizedBox(height: 20),
          Text(
            'Fetching stream…',
            style: TextStyle(color: Colors.white70, fontSize: 15),
          ),
          SizedBox(height: 6),
          Text(
            'This can take a few seconds.',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
        ),
      ),
    );
  }
}

/// Neutral empty state shown when the episode resolved but has no playable
/// sources. Deliberately calmer than [_PlayerErrorView] (no red error icon):
/// it's an expected outcome, and a Retry lets the user try again later.
class _NoSourcesView extends StatelessWidget {
  const _NoSourcesView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: _CenteredScrollable(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_off_outlined,
              color: Colors.white54, size: 52),
          const SizedBox(height: 16),
          const Text(
            'No streaming sources available',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This episode has no playable servers right now. '
            'Please check back later.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
          ),
        ],
        ),
      ),
    );
  }
}

/// Error placeholder with a Retry button for unstable/expired scraped links.
class _PlayerErrorView extends StatelessWidget {
  const _PlayerErrorView({required this.failure, required this.onRetry});

  final Failure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: _CenteredScrollable(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 52),
          const SizedBox(height: 16),
          Text(
            failure.message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          const SizedBox(height: 8),
          const Text(
            'The stream link may be temporary or unavailable.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
        ),
      ),
    );
  }
}

/// Centers its child inside the available space but lets it scroll instead of
/// overflowing when the space is too short (e.g. inside the player's fixed 16:9
/// box on small screens). Prevents "BOTTOM OVERFLOWED" RenderFlex errors while
/// keeping the content visually centered whenever it fits.
class _CenteredScrollable extends StatelessWidget {
  const _CenteredScrollable({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const padding = EdgeInsets.all(24);
        return SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.hasBoundedHeight
                  ? (constraints.maxHeight - padding.vertical)
                      .clamp(0.0, double.infinity)
                  : 0,
            ),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}
