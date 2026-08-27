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
  // Catalog endpoints
  // ---------------------------------------------------------------------------
  static const String latestEpisodes = '/episodes/latest';
  static const String trending = '/anime/trending';
  static const String categories = '/categories';

  /// Details for a single anime: `/anime/{id}`.
  static String animeDetails(String animeId) => '/anime/$animeId';

  /// Episode list for an anime: `/anime/{id}/episodes`.
  ///
  /// The caller passes a `lang` query parameter (`ar` / `en`) so the backend
  /// returns the episode servers for the selected language.
  static String animeEpisodes(String animeId) => '/anime/$animeId/episodes';

  /// On-the-fly stream resolution: `/stream/{episodeId}`.
  ///
  /// The backend scrapes the source and returns a direct, playable video URL.
  static String streamLink(String episodeId) => '/stream/$episodeId';

  // ---------------------------------------------------------------------------
  // Favorites endpoints (cloud, authenticated)
  // ---------------------------------------------------------------------------
  static const String favorites = '/favorites';

  /// Add / remove a single favorite: `/favorites/{animeId}`.
  static String favorite(String animeId) => '/favorites/$animeId';
}
