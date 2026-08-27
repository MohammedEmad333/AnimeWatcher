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
      subtitle: _buildSubtitle(context),
      trailing: _buildTrailing(context),
    );
  }

  /// Episode title, with an optional "Filler" marker when flagged by metadata.
  Widget? _buildSubtitle(BuildContext context) {
    final hasTitle = episode.title.isNotEmpty;
    if (!hasTitle && !episode.isFiller) return null;
    return Row(
      children: [
        if (hasTitle)
          Flexible(
            child: Text(
              episode.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (episode.isFiller) ...[
          if (hasTitle) const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.18),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Filler',
              style: TextStyle(fontSize: 10, color: Colors.orangeAccent),
            ),
          ),
        ],
      ],
    );
  }

  /// Prefers the air date, then a duration label, else a play affordance.
  Widget _buildTrailing(BuildContext context) {
    final label =
        episode.airedLabel.isNotEmpty ? episode.airedLabel : episode.durationLabel;
    if (label.isEmpty) return const Icon(Icons.play_arrow_rounded);
    return Text(label, style: Theme.of(context).textTheme.bodySmall);
  }
}
