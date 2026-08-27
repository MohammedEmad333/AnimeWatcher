import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/shimmer_loaders.dart';
import '../../../../shared/models/anime.dart';
import '../../../../shared/widgets/anime_card.dart';

/// Renders a horizontally-scrolling carousel of [AnimeCard]s from an
/// [AsyncValue], handling Loading / Success / Error states inline.
class HorizontalAnimeList extends StatelessWidget {
  const HorizontalAnimeList({
    super.key,
    required this.state,
    required this.onTapAnime,
    required this.onRetry,
    this.height = 220,
    this.subtitleBuilder,
  });

  final AsyncValue<List<Anime>> state;
  final void Function(Anime anime) onTapAnime;
  final VoidCallback onRetry;
  final double height;

  /// Optional muted line shown under each card's title (e.g. the primary
  /// genre). Returns null/empty to omit it for a given title.
  final String? Function(Anime anime)? subtitleBuilder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: state.when(
        loading: () => ShimmerLoaders.animeCarousel(height: height),
        error: (error, _) => ErrorView(
          failure: error.asFailure,
          onRetry: onRetry,
        ),
        data: (animeList) {
          if (animeList.isEmpty) {
            return const Center(child: Text('Nothing here yet.'));
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: animeList.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final anime = animeList[i];
              return AnimeCard(
                anime: anime,
                onTap: () => onTapAnime(anime),
                subtitle: subtitleBuilder?.call(anime),
              );
            },
          );
        },
      ),
    );
  }
}
