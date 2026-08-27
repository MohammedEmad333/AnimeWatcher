import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failures.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/shimmer_loaders.dart';
import '../../../shared/models/anime.dart';
import '../../../shared/widgets/anime_card.dart';
import '../../auth/presentation/auth_screen.dart';
import '../../auth/providers/auth_providers.dart';
import '../../details/presentation/anime_details_screen.dart';
import '../providers/favorites_providers.dart';

/// A grid of the anime the user has saved to the cloud.
///
/// Renders the three states: Loading (shimmer grid), Success (grid), Error
/// (retry). When the user is signed out, prompts them to sign in first.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final favoritesState = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Library')),
      body: !isAuthenticated
          ? _SignInPrompt(
              onSignedIn: () => ref.read(favoritesProvider.notifier).refresh(),
            )
          : favoritesState.when(
              loading: () => ShimmerLoaders.animeGrid(),
              error: (error, _) => ErrorView(
                failure: error.asFailure,
                onRetry: () => ref.read(favoritesProvider.notifier).refresh(),
              ),
              data: (favorites) => favorites.isEmpty
                  ? const _EmptyState()
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.read(favoritesProvider.notifier).refresh(),
                      child: _FavoritesGrid(favorites: favorites),
                    ),
            ),
    );
  }
}

class _FavoritesGrid extends ConsumerWidget {
  const _FavoritesGrid({required this.favorites});

  final List<Anime> favorites;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
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
          width: null,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  AnimeDetailsScreen(animeId: anime.id, preview: anime),
            ),
          ),
          trailing: _RemoveButton(
            onTap: () => _remove(context, ref, anime),
          ),
        );
      },
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, Anime anime) async {
    try {
      await ref.read(favoritesProvider.notifier).remove(anime.id);
      if (context.mounted) {
        AppSnackBar.showMessage(context, 'Removed "${anime.title}"');
      }
    } on Failure catch (failure) {
      if (context.mounted) AppSnackBar.showFailure(context, failure);
    }
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

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt({required this.onSignedIn});

  final VoidCallback onSignedIn;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 64, color: Colors.white38),
          const SizedBox(height: 16),
          Text(
            'Sign in to sync your Library',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              final signedIn = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const AuthScreen()),
              );
              if (signedIn == true) onSignedIn();
            },
            icon: const Icon(Icons.login),
            label: const Text('Sign in'),
          ),
        ],
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
