import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failures.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shimmer_loaders.dart';
import '../../../shared/models/anime.dart';
import '../../../shared/models/episode.dart';
import '../../auth/presentation/auth_screen.dart';
import '../../auth/providers/auth_providers.dart';
import '../../catalog/providers/catalog_providers.dart';
import '../../details/presentation/anime_details_screen.dart';
import '../../favorites/presentation/favorites_screen.dart';
import '../../player/presentation/video_player_screen.dart';
import '../../search/presentation/search_screen.dart';
import 'widgets/episode_poster_card.dart';
import 'widgets/horizontal_anime_list.dart';
import 'widgets/section_header.dart';
import 'widgets/spotlight_carousel.dart';

/// Home feed, styled after an Arabic anime-streaming layout: a spotlight
/// carousel, a "New Episodes" rail, two poster rails (newly added / most
/// watched) and the category chips.
///
/// The screen is laid out right-to-left (Arabic). Each section is backed by an
/// independent provider so it can load, refresh and error out on its own;
/// pull-to-refresh re-fetches every feed.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(latestEpisodesProvider);
    final trending = ref.watch(trendingAnimeProvider);
    final newlyAdded = ref.watch(newlyAddedAnimeProvider);
    final categories = ref.watch(categoriesProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        drawer: const _HomeDrawer(),
        appBar: AppBar(
          centerTitle: true,
          title: const Text('الصفحة الرئيسية'),
          actions: [
            IconButton(
              tooltip: 'بحث',
              icon: const Icon(Icons.search),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              ),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(latestEpisodesProvider);
            ref.invalidate(trendingAnimeProvider);
            ref.invalidate(newlyAddedAnimeProvider);
            ref.invalidate(categoriesProvider);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 12),
              _Spotlight(
                state: trending,
                onTap: (a) => _openDetails(context, a),
              ),
              SectionHeader(
                title: 'الحلقات الجديدة',
                onSeeAll: () => _openSearch(context),
              ),
              _NewEpisodesRow(
                state: latest,
                onTapEpisode: (e) => _openPlayer(context, e),
                onRetry: () => ref.invalidate(latestEpisodesProvider),
              ),
              SectionHeader(
                title: 'أحدث الأعمال المضافة',
                onSeeAll: () => _openSearch(context),
              ),
              HorizontalAnimeList(
                state: newlyAdded,
                onTapAnime: (a) => _openDetails(context, a),
                onRetry: () => ref.invalidate(newlyAddedAnimeProvider),
                subtitleBuilder: _primaryGenre,
              ),
              SectionHeader(
                title: 'الأنمي الأكثر مشاهدة',
                onSeeAll: () => _openSearch(context),
              ),
              HorizontalAnimeList(
                state: trending,
                onTapAnime: (a) => _openDetails(context, a),
                onRetry: () => ref.invalidate(trendingAnimeProvider),
                subtitleBuilder: _primaryGenre,
              ),
              const SectionHeader(title: 'التصنيفات'),
              _CategoriesRow(
                state: categories,
                onRetry: () => ref.invalidate(categoriesProvider),
                onTapCategory: (_) => _openSearch(context),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// The primary genre of a title, used as the muted line under each poster.
  static String? _primaryGenre(Anime a) =>
      a.genres.isNotEmpty ? a.genres.first : null;

  void _openSearch(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SearchScreen()),
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

/// Spotlight carousel, backed by the trending feed, with a shimmer/skeleton
/// while loading and a graceful empty state on error.
class _Spotlight extends StatelessWidget {
  const _Spotlight({required this.state, required this.onTap});

  final AsyncValue<List<Anime>> state;
  final void Function(Anime) onTap;

  @override
  Widget build(BuildContext context) {
    return state.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6),
        child: _SpotlightSkeleton(),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return SpotlightCarousel(items: items, onTap: onTap);
      },
    );
  }
}

class _SpotlightSkeleton extends StatelessWidget {
  const _SpotlightSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 230,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }
}

/// Horizontal rail of the most recent episodes across all series, rendered as
/// poster cards with an amber episode-number badge.
class _NewEpisodesRow extends StatelessWidget {
  const _NewEpisodesRow({
    required this.state,
    required this.onTapEpisode,
    required this.onRetry,
    this.height = 220,
  });

  final AsyncValue<List<Episode>> state;
  final void Function(Episode) onTapEpisode;
  final VoidCallback onRetry;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: state.when(
        loading: () => ShimmerLoaders.animeCarousel(height: height),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(child: Text(error.asFailure.message)),
              TextButton(onPressed: onRetry, child: const Text('إعادة')),
            ],
          ),
        ),
        data: (episodes) {
          if (episodes.isEmpty) {
            return const Center(child: Text('لا توجد حلقات جديدة.'));
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: episodes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final e = episodes[i];
              return EpisodePosterCard(
                episode: e,
                onTap: () => onTapEpisode(e),
              );
            },
          );
        },
      ),
    );
  }
}

/// Navigation drawer with the app's other destinations and the auth action.
class _HomeDrawer extends ConsumerWidget {
  const _HomeDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'AnimeWatcher',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.accent,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('الصفحة الرئيسية'),
              onTap: () => Navigator.of(context).pop(),
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('بحث'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite_border),
              title: const Text('المفضلة'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FavoritesScreen()),
                );
              },
            ),
            const Divider(),
            if (isAuthenticated)
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('تسجيل الخروج'),
                onTap: () {
                  Navigator.of(context).pop();
                  ref.read(authControllerProvider.notifier).logout();
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('تسجيل الدخول'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Wrapping chips of available categories/genres.
class _CategoriesRow extends StatelessWidget {
  const _CategoriesRow({
    required this.state,
    required this.onRetry,
    required this.onTapCategory,
  });

  final AsyncValue<List<String>> state;
  final VoidCallback onRetry;
  final void Function(String category) onTapCategory;

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
            TextButton(onPressed: onRetry, child: const Text('إعادة')),
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
              ActionChip(
                label: Text(c),
                onPressed: () => onTapCategory(c),
              ),
          ],
        ),
      ),
    );
  }
}
