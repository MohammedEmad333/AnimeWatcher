import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/snackbar_utils.dart';
import '../../../shared/models/anime.dart';
import '../../../shared/widgets/anime_card.dart';
import '../../details/presentation/anime_details_screen.dart';
import '../providers/favorites_providers.dart';

/// A grid of anime the user has saved locally (Hive-backed).
///
/// Reads directly from [favoritesProvider] (the in-memory source of truth kept
/// in sync with local storage), so removals reflect immediately.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Library')),
      body: favorites.isEmpty
          ? const _EmptyState()
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate:
                  const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 170,
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
                childAspectRatio: 0.62,
              ),
              itemCount: favorites.length,
              itemBuilder: (_, i) {
                final anime = favorites[i];
                return AnimeCard(
                  anime: anime,
                  width: null, // fill the grid cell
                  onTap: () => _openDetails(context, anime),
                  trailing: _RemoveButton(
                    onTap: () => _remove(context, ref, anime),
                  ),
                );
              },
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

  void _remove(BuildContext context, WidgetRef ref, Anime anime) {
    ref.read(favoritesProvider.notifier).remove(anime.id);
    AppSnackBar.showMessage(context, 'Removed "${anime.title}" from Library');
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Icon(Icons.favorite, color: Colors.redAccent, size: 18),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.favorite_border, size: 64, color: Colors.white38),
          const SizedBox(height: 16),
          Text(
            'Your Library is empty',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          const Text(
            'Save anime to find them here.',
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
