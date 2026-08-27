import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failures.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../shared/models/anime.dart';
import '../../../shared/models/episode.dart';
import '../../../shared/widgets/episode_tile.dart';
import '../../catalog/providers/catalog_providers.dart';
import '../../favorites/providers/favorites_providers.dart';
import '../../player/presentation/video_player_screen.dart';

/// Details for a single anime: cover, synopsis, rating, and its episode list.
///
/// An optional [preview] (passed from the list the user tapped) lets the header
/// render instantly while the full details load, avoiding a blank screen.
class AnimeDetailsScreen extends ConsumerWidget {
  const AnimeDetailsScreen({
    super.key,
    required this.animeId,
    this.preview,
  });

  final String animeId;
  final Anime? preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsState = ref.watch(animeDetailsProvider(animeId));
    final episodesState = ref.watch(animeEpisodesProvider(animeId));

    // Prefer freshly-loaded details; fall back to the preview while loading.
    final anime = detailsState.valueOrNull ?? preview;

    return Scaffold(
      body: detailsState.isLoading && anime == null
          ? const LoadingIndicator(message: 'Loading details…')
          : detailsState.hasError && anime == null
              ? ErrorView(
                  failure: detailsState.error!.asFailure,
                  onRetry: () => ref.invalidate(animeDetailsProvider(animeId)),
                )
              : CustomScrollView(
                  slivers: [
                    _DetailsHeader(anime: anime!),
                    _FavoriteAndMeta(anime: anime),
                    _SynopsisSection(anime: anime),
                    _EpisodesSection(
                      state: episodesState,
                      onTapEpisode: (e) => _openPlayer(context, e),
                      onRetry: () =>
                          ref.invalidate(animeEpisodesProvider(animeId)),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
    );
  }

  void _openPlayer(BuildContext context, Episode episode) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VideoPlayerScreen(episode: episode)),
    );
  }
}

/// Collapsing app bar showing the cover art.
class _DetailsHeader extends StatelessWidget {
  const _DetailsHeader({required this.anime});

  final Anime anime;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          anime.title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (anime.coverUrl.isNotEmpty)
              CachedNetworkImage(imageUrl: anime.coverUrl, fit: BoxFit.cover)
            else
              const ColoredBox(color: Colors.white10),
            // Gradient so the title stays legible over the artwork.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rating, episode count and the favorite toggle.
class _FavoriteAndMeta extends ConsumerWidget {
  const _FavoriteAndMeta({required this.anime});

  final Anime anime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(isFavoriteProvider(anime.id));

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Row(
          children: [
            if (anime.rating > 0) ...[
              const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
              const SizedBox(width: 4),
              Text(anime.rating.toStringAsFixed(1)),
              const SizedBox(width: 16),
            ],
            if (anime.episodeCount > 0) ...[
              const Icon(Icons.playlist_play_rounded, size: 20),
              const SizedBox(width: 4),
              Text('${anime.episodeCount} eps'),
            ],
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: () =>
                  ref.read(favoritesProvider.notifier).toggle(anime),
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
              ),
              label: Text(isFavorite ? 'Saved' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Genres + synopsis text.
class _SynopsisSection extends StatelessWidget {
  const _SynopsisSection({required this.anime});

  final Anime anime;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (anime.genres.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final g in anime.genres)
                    Chip(
                      label: Text(g),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            if (anime.synopsis.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Synopsis',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                anime.synopsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The vertical episode list (its own Loading / Success / Error states).
class _EpisodesSection extends StatelessWidget {
  const _EpisodesSection({
    required this.state,
    required this.onTapEpisode,
    required this.onRetry,
  });

  final AsyncValue<List<Episode>> state;
  final void Function(Episode) onTapEpisode;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return state.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, _) => SliverToBoxAdapter(
        child: SizedBox(
          height: 200,
          child: ErrorView(failure: error.asFailure, onRetry: onRetry),
        ),
      ),
      data: (episodes) {
        if (episodes.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No episodes available yet.')),
            ),
          );
        }
        return SliverList.builder(
          itemCount: episodes.length,
          itemBuilder: (_, i) => EpisodeTile(
            episode: episodes[i],
            onTap: () => onTapEpisode(episodes[i]),
          ),
        );
      },
    );
  }
}
