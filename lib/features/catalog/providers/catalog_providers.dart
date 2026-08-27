import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../shared/models/anime.dart';
import '../../../shared/models/episode.dart';
import '../data/catalog_remote_datasource.dart';
import '../data/catalog_repository.dart';

/// Wires the catalog datasource + repository into the provider graph.
final _catalogDataSourceProvider = Provider<CatalogRemoteDataSource>(
  (ref) => CatalogRemoteDataSource(ref.watch(dioClientProvider)),
);

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(ref.watch(_catalogDataSourceProvider)),
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

final animeEpisodesProvider =
    FutureProvider.autoDispose.family<List<Episode>, String>(
  (ref, animeId) => ref.watch(catalogRepositoryProvider).getEpisodes(animeId),
);
