import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failures.dart';
import '../../../core/widgets/shimmer_loaders.dart';
import '../../../shared/models/anime.dart';
import '../../../shared/models/episode.dart';
import '../../../shared/widgets/episode_tile.dart';
import '../../auth/presentation/auth_screen.dart';
import '../../auth/providers/auth_providers.dart';
import '../../catalog/providers/catalog_providers.dart';
import '../../details/presentation/anime_details_screen.dart';
import '../../favorites/presentation/favorites_screen.dart';
import '../../player/presentation/video_player_screen.dart';
import '../../search/presentation/search_screen.dart';
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
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Favorites',
            icon: const Icon(Icons.favorite_border),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FavoritesScreen()),
            ),
          ),
          const _AccountAction(),
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
      loading: () => ShimmerLoaders.episodeList(count: 3),
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

/// App-bar action reflecting auth state: a login icon when signed out, or a
/// menu with "Sign out" when signed in.
class _AccountAction extends ConsumerWidget {
  const _AccountAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    if (!isAuthenticated) {
      return IconButton(
        tooltip: 'Sign in',
        icon: const Icon(Icons.login),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
        ),
      );
    }

    return PopupMenuButton<String>(
      icon: const Icon(Icons.account_circle),
      onSelected: (value) {
        if (value == 'logout') {
          ref.read(authControllerProvider.notifier).logout();
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'logout', child: Text('Sign out')),
      ],
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
