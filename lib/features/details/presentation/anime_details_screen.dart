import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failures.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/shimmer_loaders.dart';
import '../../../shared/models/anime.dart';
import '../../../shared/models/content_language.dart';
import '../../../shared/models/episode.dart';
import '../../../shared/widgets/episode_tile.dart';
import '../../auth/presentation/auth_screen.dart';
import '../../auth/providers/auth_providers.dart';
import '../../catalog/providers/catalog_providers.dart';
import '../../favorites/providers/favorites_providers.dart';
import '../../player/presentation/video_player_screen.dart';
import 'widgets/language_toggle.dart';

/// Details for a single anime: cover, synopsis, rating, an authenticated
/// "Add to Favorites" action, an Arabic / English language toggle, and the
/// episode list for the selected language.
///
/// An optional [preview] renders the header instantly while full details load.
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
    final anime = detailsState.valueOrNull ?? preview;

    if (detailsState.isLoading && anime == null) {
      return const Scaffold(
        body: LoadingIndicator(message: 'Loading details…'),
      );
    }
    if (detailsState.hasError && anime == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          failure: detailsState.error!.asFailure,
          onRetry: () => ref.invalidate(animeDetailsProvider(animeId)),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _DetailsHeader(anime: anime!),
          _MetaAndFavorite(anime: anime),
          _SynopsisSection(anime: anime),
          _EpisodesSectionHeader(animeId: animeId),
          _EpisodesSliver(animeId: animeId, episodeCount: anime.episodeCount),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

/// Collapsing app bar with the cover art.
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

/// Rating, episode count, and the authenticated favorite toggle.
class _MetaAndFavorite extends ConsumerWidget {
  const _MetaAndFavorite({required this.anime});

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
              onPressed: () => _toggleFavorite(context, ref),
              icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
              label: Text(isFavorite ? 'Saved' : 'Add to Favorites'),
            ),
          ],
        ),
      ),
    );
  }

  /// Requires authentication: if signed out, routes to the auth screen first,
  /// then performs the cloud add/remove and surfaces any error via SnackBar.
  Future<void> _toggleFavorite(BuildContext context, WidgetRef ref) async {
    if (!ref.read(isAuthenticatedProvider)) {
      final signedIn = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
      if (signedIn != true) return;
    }

    try {
      await ref.read(favoritesProvider.notifier).toggle(anime);
      if (context.mounted) {
        final saved = ref.read(isFavoriteProvider(anime.id));
        AppSnackBar.showMessage(
          context,
          saved ? 'Added to Favorites' : 'Removed from Favorites',
        );
      }
    } on Failure catch (failure) {
      if (context.mounted) AppSnackBar.showFailure(context, failure);
    }
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
              Text('Synopsis', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(anime.synopsis,
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Episodes" title with the language toggle on the right.
class _EpisodesSectionHeader extends ConsumerWidget {
  const _EpisodesSectionHeader({required this.animeId});

  final String animeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedLanguageProvider);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Row(
          children: [
            Text(
              'Episodes',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            LanguageToggle(
              selected: selected,
              // Updating state re-keys the episodes family below, which
              // triggers a fetch for the newly-selected language.
              onChanged: (lang) =>
                  ref.read(selectedLanguageProvider.notifier).state = lang,
            ),
          ],
        ),
      ),
    );
  }
}

/// The episode list for the selected language (Loading / Success / Error).
class _EpisodesSliver extends ConsumerWidget {
  const _EpisodesSliver({required this.animeId, this.episodeCount = 0});

  final String animeId;

  /// Known episode count from the loaded details, used as a fallback when the
  /// Jikan episode metadata is unavailable (see `CatalogRepository.getEpisodes`).
  final int episodeCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(selectedLanguageProvider);
    final query = EpisodeQuery(animeId, language, episodeCount: episodeCount);
    final episodesState = ref.watch(animeEpisodesProvider(query));

    return episodesState.when(
      loading: () => SliverToBoxAdapter(child: ShimmerLoaders.episodeList()),
      error: (error, _) => SliverToBoxAdapter(
        child: SizedBox(
          height: 220,
          child: ErrorView(
            failure: error.asFailure,
            onRetry: () => ref.invalidate(animeEpisodesProvider(query)),
          ),
        ),
      ),
      data: (episodes) {
        if (episodes.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No ${language.label} episodes available yet.',
                ),
              ),
            ),
          );
        }
        return SliverList.builder(
          itemCount: episodes.length,
          itemBuilder: (_, i) => EpisodeTile(
            episode: episodes[i],
            onTap: () => _openPlayer(context, episodes[i]),
          ),
        );
      },
    );
  }

  void _openPlayer(BuildContext context, Episode episode) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VideoPlayerScreen(episode: episode)),
    );
  }
}
