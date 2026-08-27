import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/episode.dart';

/// A poster-style card for a freshly-released [Episode], used by the Home
/// "الحلقات الجديدة" (New Episodes) rail.
///
/// Mirrors [AnimeCard]'s proportions but overlays an amber "الحلقة N" badge on
/// the cover and shows the series title beneath, matching the reference design.
class EpisodePosterCard extends StatelessWidget {
  const EpisodePosterCard({
    super.key,
    required this.episode,
    required this.onTap,
    this.width = 140,
  });

  final Episode episode;
  final VoidCallback onTap;
  final double width;

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
                    if (episode.thumbnailUrl.isEmpty)
                      const ColoredBox(
                        color: Colors.white10,
                        child: Icon(Icons.movie_outlined,
                            color: Colors.white38, size: 40),
                      )
                    else
                      CachedNetworkImage(
                        imageUrl: episode.thumbnailUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            const ColoredBox(color: Colors.white10),
                        errorWidget: (_, __, ___) => const ColoredBox(
                          color: Colors.white10,
                          child: Icon(Icons.broken_image_outlined,
                              color: Colors.white38),
                        ),
                      ),
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 8,
                      child: Align(
                        alignment: Alignment.center,
                        child: _EpisodeBadge(number: episode.number),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              episode.title.isEmpty ? 'الحلقة ${episode.number}' : episode.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EpisodeBadge extends StatelessWidget {
  const _EpisodeBadge({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.accent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'الحلقة $number',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
