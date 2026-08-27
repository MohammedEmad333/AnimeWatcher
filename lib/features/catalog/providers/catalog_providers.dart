import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../shared/models/anime.dart';
import '../../../shared/models/content_language.dart';
import '../../../shared/models/episode.dart';
import '../data/catalog_remote_datasource.dart';
import '../data/catalog_repository.dart';
import '../data/jikan_remote_datasource.dart';

/// Wires the catalog datasources + repository into the provider graph.
final _catalogDataSourceProvider = Provider<CatalogRemoteDataSource>(
  (ref) => CatalogRemoteDataSource(ref.watch(dioClientProvider)),
);

/// Direct-to-Jikan datasource (its own Dio, no backend base URL / JWT).
final _jikanDataSourceProvider = Provider<JikanRemoteDataSource>(
  (ref) => JikanRemoteDataSource(),
);

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(
    ref.watch(_catalogDataSourceProvider),
    ref.watch(_jikanDataSourceProvider),
  ),
);

// --- Home feeds --------------------------------------------------------------
// Each feed is its own `FutureProvider` so the Home screen can render, refresh
// and error-handle the three sections independently. `AsyncValue` encodes the
// Loading / Success / Error UI states for free.

final latestEpisodesProvider = FutureProvider.autoDispose<List<Episode>>(
  (ref) => ref.watch(catalogRepositoryProvider).getLatestEpisodes(),
);

final trendingAnimeProvider = FutureProvider.autoDispose<List<Anime>>(
  (ref) => ref.watch(catalogRepositoryProvider).getTrending(),
);

final categoriesProvider = FutureProvider.autoDispose<List<String>>(
  (ref) => ref.watch(catalogRepositoryProvider).getCategories(),
);

// --- Details -----------------------------------------------------------------
// Family providers keyed by anime id.

final animeDetailsProvider =
    FutureProvider.autoDispose.family<Anime, String>(
  (ref, animeId) =>
      ref.watch(catalogRepositoryProvider).getAnimeDetails(animeId),
);

/// The language currently selected in the Details toggle. Global so the choice
/// persists as the user browses between titles. Defaults to Arabic.
final selectedLanguageProvider =
    StateProvider<ContentLanguage>((ref) => ContentLanguage.arabic);

/// Composite key for the episodes family: episodes depend on both the anime and
/// the chosen language, so switching the toggle re-fetches automatically.
class EpisodeQuery extends Equatable {
  const EpisodeQuery(this.animeId, this.language);

  final String animeId;
  final ContentLanguage language;

  @override
  List<Object?> get props => [animeId, language];
}

final animeEpisodesProvider =
    FutureProvider.autoDispose.family<List<Episode>, EpisodeQuery>(
  (ref, query) => ref.watch(catalogRepositoryProvider).getEpisodes(
        query.animeId,
        languageCode: query.language.code,
      ),
);
