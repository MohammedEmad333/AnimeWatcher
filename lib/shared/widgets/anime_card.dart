import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/anime.dart';

/// A poster-style card for a single [Anime].
///
/// Reused by the Home horizontal lists and the Favorites grid. The [width] is
/// nullable so it can either take a fixed width (horizontal carousels) or fill
/// its grid cell (Favorites).
class AnimeCard extends StatelessWidget {
  const AnimeCard({
    super.key,
    required this.anime,
    required this.onTap,
    this.width = 140,
    this.trailing,
    this.subtitle,
  });

  final Anime anime;
  final VoidCallback onTap;
  final double? width;

  /// Optional overlay in the top-right corner (e.g. a favorite toggle).
  final Widget? trailing;

  /// Optional muted line shown beneath the title (e.g. the primary genre),
  /// mirroring the "type" label under each poster in the home design.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _Cover(url: anime.coverUrl),
                    if (anime.rating > 0)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: _RatingBadge(rating: anime.rating),
                      ),
                    if (trailing != null)
                      Positioned(top: 4, right: 4, child: trailing!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              anime.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white54,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return const _CoverFallback();
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => const ColoredBox(color: Colors.white10),
      errorWidget: (_, __, ___) => const _CoverFallback(),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.white10,
      child: Icon(Icons.movie_outlined, color: Colors.white38, size: 40),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
