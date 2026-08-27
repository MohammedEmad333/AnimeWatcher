/// Centralized API configuration.
///
/// All endpoints are declared here so that the base URL and paths live in a
/// single place and can be swapped between environments (dev / staging / prod).
class ApiConstants {
  const ApiConstants._();

  /// Base URL of the custom backend.
  ///
  /// The backend performs on-the-fly scraping and exposes catalog + streaming
  /// endpoints. Replace with your deployed host.
  static const String baseUrl = 'https://api.animewatcher.example.com/v1';

  // ---------------------------------------------------------------------------
  // Timeouts
  // ---------------------------------------------------------------------------
  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Scraping the stream link can take longer than a normal request, so give it
  // its own, more generous timeout.
  static const Duration streamReceiveTimeout = Duration(seconds: 45);

  // ---------------------------------------------------------------------------
  // Auth endpoints (Cloud Sync)
  // ---------------------------------------------------------------------------
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String logout = '/auth/logout';
  static const String currentUser = '/auth/me';

  // ---------------------------------------------------------------------------
  // Direct Jikan (MyAnimeList) API
  // ---------------------------------------------------------------------------
  // The catalog's Trending + Details screens call Jikan **directly** from the
  // app (see JikanRemoteDataSource). Jikan is public and needs no key, so this
  // keeps the catalog working even when the backend is hosted somewhere that
  // blocks outbound requests (e.g. InfinityFree). The backend's own catalog
  // proxy (`/anime/trending`, `/anime/details/{id}`) remains available for
  // hosts that allow outbound cURL.
  static const String jikanBaseUrl = 'https://api.jikan.moe/v4';
  static const String jikanTopAnime = '/top/anime';

  /// Full details for one title on Jikan: `/anime/{id}/full`.
  static String jikanAnimeFull(String id) => '/anime/$id/full';

  // ---------------------------------------------------------------------------
  // Catalog endpoints (custom backend)
  // ---------------------------------------------------------------------------
  static const String latestEpisodes = '/episodes/latest';

  /// Backend Jikan proxy (used only when the backend host allows outbound
  /// cURL). The app currently sources trending from Jikan directly instead.
  static const String trending = '/anime/trending';
  static const String categories = '/categories';

  /// Backend details proxy: `GET /api/anime/details/{id}` (outbound-capable
  /// hosts only). The app currently sources details from Jikan directly.
  static String animeDetails(String animeId) => '/anime/details/$animeId';

  /// Episode list for an anime: `/anime/{id}/episodes`.
  ///
  /// The caller passes a `lang` query parameter (`ar` / `en`) so the backend
  /// returns the episode servers for the selected language.
  static String animeEpisodes(String animeId) => '/anime/$animeId/episodes';

  /// On-the-fly video source resolution:
  /// `GET /api/episodes/sources?episode_id={id}&lang={ar|en}`.
  ///
  /// The backend's ScraperService resolves one or more direct, playable links
  /// (MP4 / HLS). Callers pass `episode_id` and `lang` as query parameters
  /// (see [DioClient.get]), so this is a plain constant, not a builder.
  static const String episodeSources = '/episodes/sources';

  // ---------------------------------------------------------------------------
  // Favorites endpoints (cloud, authenticated)
  // ---------------------------------------------------------------------------
  // The backend exposes a single collection endpoint; the anime id (and, for
  // add, the denormalized title/cover) travel in the JSON body.
  static const String favorites = '/favorites';

  // ---------------------------------------------------------------------------
  // Watch-history endpoints (cloud, authenticated)
  // ---------------------------------------------------------------------------
  // GET  /history?anime_id=..&episode_id=..  → resume position
  // POST /history                            → upsert playback_time
  static const String history = '/history';
}
