import '../../../core/error/failures.dart';
import '../../../shared/models/anime.dart';
import '../../../shared/models/episode.dart';
import '../../../shared/models/genre.dart';
import 'jikan_remote_datasource.dart';

/// Repository for catalog data.
///
/// Bridges the presentation and data layers: it invokes the remote datasource
/// and converts any thrown [Exception] into a presentation-safe [Failure], so
/// the UI never handles raw exceptions. On success it returns domain models
/// directly; on failure it throws a [Failure] (captured by Riverpod's
/// `AsyncValue`).
///
/// The read-only catalog — Latest Episodes, Trending, Categories, Details,
/// Episodes and Search — is sourced from Jikan **directly** ([_jikan]) so it
/// keeps working regardless of the backend host's outbound policy or which
/// endpoints it implements. Playback/auth-bound data (stream sources, history)
/// still goes through the backend from their own repositories.
class CatalogRepository {
  const CatalogRepository(this._jikan);

  final JikanRemoteDataSource _jikan;

  Future<List<Episode>> getLatestEpisodes() =>
      _guard(() => _jikan.getLatestEpisodes());

  Future<List<Anime>> getTrending() => _guard(() => _jikan.getTrending());

  Future<List<String>> getCategories() =>
      _guard(() => _jikan.getCategories());

  Future<Anime> getAnimeDetails(String id) =>
      _guard(() => _jikan.getAnimeDetails(id));

  /// Episode metadata (titles, air dates, filler flags) comes from Jikan so the
  /// Details screen shows real data regardless of the backend host. The
  /// [languageCode] is retained for the player's later source resolution; the
  /// metadata itself is language-independent (public APIs are EN/romaji).
  Future<List<Episode>> getEpisodes(String id, {required String languageCode}) =>
      _guard(() => _jikan.getEpisodes(id));

  /// Anime search by title, optionally filtered by a genre id.
  Future<List<Anime>> searchAnime({
    String query = '',
    String? genreId,
    int page = 1,
  }) =>
      _guard(() => _jikan.searchAnime(
            query: query,
            genreId: genreId,
            page: page,
          ));

  /// All genres (id + name) for the Search screen's filter chips.
  Future<List<Genre>> getGenres() => _guard(() => _jikan.getGenres());

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
