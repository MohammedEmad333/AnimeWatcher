import '../../../core/error/failures.dart';
import '../../../shared/models/anime.dart';
import '../../../shared/models/episode.dart';
import 'catalog_remote_datasource.dart';
import 'jikan_remote_datasource.dart';

/// Repository for catalog data.
///
/// Bridges the presentation and data layers: it invokes the remote datasource
/// and converts any thrown [Exception] into a presentation-safe [Failure], so
/// the UI never handles raw exceptions. On success it returns domain models
/// directly; on failure it throws a [Failure] (captured by Riverpod's
/// `AsyncValue`).
///
/// Trending + Details are sourced from Jikan **directly** ([_jikan]) so the
/// catalog keeps working even when the backend host blocks outbound requests;
/// everything else goes through our backend ([_remote]).
class CatalogRepository {
  const CatalogRepository(this._remote, this._jikan);

  final CatalogRemoteDataSource _remote;
  final JikanRemoteDataSource _jikan;

  Future<List<Episode>> getLatestEpisodes() =>
      _guard(() => _remote.getLatestEpisodes());

  Future<List<Anime>> getTrending() => _guard(() => _jikan.getTrending());

  Future<List<String>> getCategories() =>
      _guard(() => _remote.getCategories());

  Future<Anime> getAnimeDetails(String id) =>
      _guard(() => _jikan.getAnimeDetails(id));

  Future<List<Episode>> getEpisodes(String id, {required String languageCode}) =>
      _guard(() => _remote.getEpisodes(id, languageCode: languageCode));

  /// Runs [action], rethrowing any error as a typed [Failure].
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Failure {
      rethrow;
    } catch (e) {
      throw Failure.fromException(e);
    }
  }
}
