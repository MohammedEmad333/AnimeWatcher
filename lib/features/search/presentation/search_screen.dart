import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failures.dart';
import '../../../core/widgets/error_view.dart';
import '../../../shared/models/anime.dart';
import '../../../shared/models/genre.dart';
import '../../../shared/widgets/anime_card.dart';
import '../../details/presentation/anime_details_screen.dart';
import '../providers/search_providers.dart';

/// Search screen: find anime by title (Jikan `/anime?q=..`) and filter by
/// genre. Results render as a poster grid; tapping opens the details screen.
///
/// The three async states (loading / results / error) are handled explicitly,
/// and a friendly empty state invites a search when nothing is queried yet.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    // Push the submitted text into the provider, which re-runs the search.
    ref.read(searchQueryProvider.notifier).state = value.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
      ),
      body: Column(
        children: [
          _SearchField(controller: _controller, onSubmitted: _submit),
          const _GenreFilterBar(),
          const Divider(height: 1),
          const Expanded(child: _SearchResults()),
        ],
      ),
    );
  }
}

/// The text input with a clear button and a search action.
class _SearchField extends ConsumerWidget {
  const _SearchField({required this.controller, required this.onSubmitted});

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        autofocus: true,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: 'Search anime by title…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      controller.clear();
                      ref.read(searchQueryProvider.notifier).state = '';
                    },
                  ),
          ),
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }
}

/// Horizontal, single-select genre filter chips (loaded from Jikan).
class _GenreFilterBar extends ConsumerWidget {
  const _GenreFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final genresState = ref.watch(searchGenresProvider);
    final selected = ref.watch(selectedGenreProvider);

    return SizedBox(
      height: 48,
      child: genresState.when(
        loading: () => const Center(
          child: SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        // Genres are a non-critical enhancement: if they fail to load, just
        // hide the bar so title search still works.
        error: (_, __) => const SizedBox.shrink(),
        data: (genres) {
          if (genres.isEmpty) return const SizedBox.shrink();
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: genres.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              if (i == 0) {
                return _GenreChip(
                  label: 'All',
                  selected: selected == null,
                  onTap: () =>
                      ref.read(selectedGenreProvider.notifier).state = null,
                );
              }
              final genre = genres[i - 1];
              return _GenreChip(
                label: genre.name,
                selected: selected?.id == genre.id,
                onTap: () => _toggle(ref, genre, selected),
              );
            },
          );
        },
      ),
    );
  }

  void _toggle(WidgetRef ref, Genre genre, Genre? selected) {
    // Tapping the active genre clears the filter; otherwise selects it.
    ref.read(selectedGenreProvider.notifier).state =
        selected?.id == genre.id ? null : genre;
  }
}

class _GenreChip extends StatelessWidget {
  const _GenreChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

/// The results grid / empty / loading / error states.
class _SearchResults extends ConsumerWidget {
  const _SearchResults();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchQueryProvider);
    final genre = ref.watch(selectedGenreProvider);
    final results = ref.watch(searchResultsProvider);

    final hasCriteria = query.isNotEmpty || genre != null;

    return results.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorView(
        failure: error.asFailure,
        onRetry: () => ref.invalidate(searchResultsProvider),
      ),
      data: (animeList) {
        if (!hasCriteria) {
          return const _SearchHint(
            icon: Icons.travel_explore,
            message: 'Search for an anime by title,\nor pick a genre to browse.',
          );
        }
        if (animeList.isEmpty) {
          return const _SearchHint(
            icon: Icons.search_off,
            message: 'No results found.\nTry a different title or genre.',
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.54,
            crossAxisSpacing: 12,
            mainAxisSpacing: 16,
          ),
          itemCount: animeList.length,
          itemBuilder: (_, i) {
            final anime = animeList[i];
            return AnimeCard(
              anime: anime,
              width: null,
              onTap: () => _openDetails(context, anime),
            );
          },
        );
      },
    );
  }

  void _openDetails(BuildContext context, Anime anime) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnimeDetailsScreen(animeId: anime.id, preview: anime),
      ),
    );
  }
}

/// Centered icon + message used for the "start searching" and "no results"
/// empty states.
class _SearchHint extends StatelessWidget {
  const _SearchHint({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Theme.of(context).disabledColor),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
