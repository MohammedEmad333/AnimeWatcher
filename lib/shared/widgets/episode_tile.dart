import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/episode.dart';

/// A list row representing a single [Episode], with a play affordance.
///
/// Used in the Anime Details episode list and the Home "Latest Episodes" feed.
class EpisodeTile extends StatelessWidget {
  const EpisodeTile({
    super.key,
    required this.episode,
    required this.onTap,
  });

  final Episode episode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 96,
          height: 56,
          child: episode.thumbnailUrl.isEmpty
              ? const ColoredBox(
                  color: Colors.white10,
                  child: Icon(Icons.play_circle_outline,
                      color: Colors.white54),
                )
              : CachedNetworkImage(
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
        ),
      ),
      title: Text(
        'Episode ${episode.number}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: episode.title.isEmpty
          ? null
          : Text(
              episode.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: episode.durationLabel.isEmpty
          ? const Icon(Icons.play_arrow_rounded)
          : Text(
              episode.durationLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
    );
  }
}
