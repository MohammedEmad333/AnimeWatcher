import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failures.dart';
import '../../../shared/models/anime.dart';
import '../../../shared/models/episode.dart';
import '../../../shared/widgets/episode_tile.dart';
import '../../catalog/providers/catalog_providers.dart';
import '../../details/presentation/anime_details_screen.dart';
import '../../favorites/presentation/favorites_screen.dart';
import '../../player/presentation/video_player_screen.dart';
import 'widgets/horizontal_anime_list.dart';
import 'widgets/section_header.dart';

/// Home feed: "Latest Episodes", "Trending Anime" and "Categories".
///
/// Each section is backed by an independent provider so it can load, refresh
/// and error out on its own. Pull-to-refresh re-fetches every feed.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(latestEpisodesProvider);
    final trending = ref.watch(trendingAnimeProvider);
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AnimeWatcher'),
        actions: [
          IconButton(
            tooltip: 'Favorites',
            icon: const Icon(Icons.favorite_border),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FavoritesScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(latestEpisodesProvider);
          ref.invalidate(trendingAnimeProvider);
          ref.invalidate(categoriesProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SectionHeader(title: 'Latest Episodes'),
            _LatestEpisodesRow(
              state: latest,
              onTapEpisode: (e) => _openPlayer(context, e),
              onRetry: () => ref.invalidate(latestEpisodesProvider),
            ),
            const SectionHeader(title: 'Trending Anime'),
            HorizontalAnimeList(
              state: trending,
              onTapAnime: (a) => _openDetails(context, a),
              onRetry: () => ref.invalidate(trendingAnimeProvider),
            ),
            const SectionHeader(title: 'Categories'),
            _CategoriesRow(
              state: categories,
              onRetry: () => ref.invalidate(categoriesProvider),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _openDetails(BuildContext context, Anime anime) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnimeDetailsScreen(animeId: anime.id, preview: anime),
      ),
    );
  }

  void _openPlayer(BuildContext context, Episode episode) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VideoPlayerScreen(episode: episode)),
    );
  }
}

/// Horizontal list of the most recent episodes across all series.
class _LatestEpisodesRow extends StatelessWidget {
  const _LatestEpisodesRow({
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
      loading: () => const SizedBox(
        height: 96,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(child: Text(error.asFailure.message)),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
      data: (episodes) {
        if (episodes.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No new episodes.'),
          );
        }
        return Column(
          children: [
            for (final e in episodes.take(6))
              EpisodeTile(episode: e, onTap: () => onTapEpisode(e)),
          ],
        );
      },
    );
  }
}

/// Wrapping chips of available categories/genres.
class _CategoriesRow extends StatelessWidget {
  const _CategoriesRow({required this.state, required this.onRetry});

  final AsyncValue<List<String>> state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return state.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(child: Text(error.asFailure.message)),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
      data: (categories) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in categories)
              Chip(label: Text(c)),
          ],
        ),
      ),
    );
  }
}
