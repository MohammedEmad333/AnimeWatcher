import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/anime.dart';
import '../../../shared/models/genre.dart';
import '../../catalog/providers/catalog_providers.dart';

/// All anime genres for the Search screen's filter chips.
final searchGenresProvider = FutureProvider.autoDispose<List<Genre>>(
  (ref) => ref.watch(catalogRepositoryProvider).getGenres(),
);

/// The active search text. Updated when the user submits the field (not on
/// every keystroke) to stay within Jikan's rate limits.
final searchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

/// The selected genre filter, or `null` for "all genres".
final selectedGenreProvider = StateProvider.autoDispose<Genre?>((ref) => null);

/// Search results for the current [searchQueryProvider] + [selectedGenreProvider].
///
/// Returns an empty list (without hitting the network) when there is neither a
/// query nor a genre selected, so the screen can show an inviting empty state.
final searchResultsProvider = FutureProvider.autoDispose<List<Anime>>((ref) {
  final query = ref.watch(searchQueryProvider);
  final genre = ref.watch(selectedGenreProvider);
  return ref.watch(catalogRepositoryProvider).searchAnime(
        query: query,
        genreId: genre?.id,
      );
});
