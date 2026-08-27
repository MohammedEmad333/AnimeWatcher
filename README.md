# AnimeWatcher

An anime **streaming & tracking** app built with Flutter. The app does **not**
host any video — it fetches direct, playable links on demand from a custom
backend that scrapes sources on the fly, then plays MP4/HLS streams with
`better_player`.

## Tech Stack

| Concern            | Choice |
| ------------------ | ------ |
| Framework          | Flutter (Dart 3, null-safe) |
| Networking         | `dio` (interceptors for error mapping, timeouts, logging) |
| State management   | `flutter_riverpod` (`AsyncValue` for Loading/Success/Error) |
| Video player       | `better_player` (MP4 + HLS/m3u8) |
| Local database     | `hive` (Favorites / Library) |
| Image caching      | `cached_network_image` |

## Architecture

Feature-first Clean Architecture. Each feature owns its `data` (datasources +
repositories), `providers` (Riverpod), and `presentation` (screens + widgets)
layers. Cross-cutting concerns live in `core/`, and reusable domain models /
widgets in `shared/`.

Error flow: **datasource** throws a typed `Exception` → **repository** converts
it to a presentation-safe `Failure` → **provider** surfaces it via `AsyncValue`
/ a sealed player state → **UI** renders a friendly message, SnackBar, or Retry
button.

## Directory Structure

```text
lib/
├── main.dart                     # Entry point: bootstrap + ProviderScope
├── app.dart                      # MaterialApp + theme + home route
├── bootstrap.dart                # One-time init (Hive setup)
│
├── core/                         # Cross-cutting infrastructure
│   ├── constants/
│   │   └── api_constants.dart    # Base URL, endpoints, timeouts
│   ├── error/
│   │   ├── exceptions.dart       # Low-level exceptions (data layer)
│   │   └── failures.dart         # Presentation-safe failures + mapping
│   ├── network/
│   │   ├── dio_client.dart       # Configured Dio wrapper (typed get/post)
│   │   └── api_interceptors.dart # Logging + error-mapping interceptors
│   ├── providers/
│   │   └── core_providers.dart   # Shared DioClient provider
│   ├── theme/
│   │   └── app_theme.dart        # Dark, cinema-style theme
│   ├── utils/
│   │   └── snackbar_utils.dart   # Friendly SnackBars (with Retry)
│   └── widgets/
│       ├── loading_indicator.dart
│       └── error_view.dart       # Reusable error state + Retry
│
├── shared/                       # Reused across features
│   ├── models/
│   │   ├── anime.dart            # + hand-written Hive TypeAdapter
│   │   ├── episode.dart
│   │   └── stream_link.dart      # Resolved MP4/HLS link (+ headers)
│   └── widgets/
│       ├── anime_card.dart       # Poster card (carousels + grid)
│       └── episode_tile.dart
│
└── features/
    ├── catalog/                  # Home feeds + details data (shared source)
    │   ├── data/
    │   │   ├── catalog_remote_datasource.dart
    │   │   └── catalog_repository.dart
    │   └── providers/
    │       └── catalog_providers.dart
    │
    ├── home/
    │   └── presentation/
    │       ├── home_screen.dart
    │       └── widgets/          # section_header, horizontal_anime_list
    │
    ├── details/
    │   └── presentation/
    │       └── anime_details_screen.dart
    │
    ├── player/                   # Dynamic link fetching + playback
    │   ├── data/
    │   │   ├── stream_remote_datasource.dart
    │   │   └── stream_repository.dart
    │   ├── providers/
    │   │   ├── player_state.dart        # sealed: Loading / Ready / Error
    │   │   └── player_providers.dart    # resolve → play → retry controller
    │   └── presentation/
    │       └── video_player_screen.dart # graceful loading + Retry
    │
    └── favorites/
        ├── data/
        │   ├── favorites_local_datasource.dart  # Hive box
        │   └── favorites_repository.dart
        ├── providers/
        │   └── favorites_providers.dart
        └── presentation/
            └── favorites_screen.dart            # grid view
```

## Dynamic Link Fetching

When a user taps an episode, the app opens `VideoPlayerScreen` and immediately
shows a loading indicator. `PlayerController`:

1. Calls `GET /stream/{episodeId}` (extended timeout — scraping is slow).
2. Receives a direct `StreamLink` (MP4 or HLS, plus any CDN headers).
3. Builds a `BetterPlayerController` and starts playback.
4. On **any** failure (resolution or mid-stream), shows a message + **Retry**
   button that re-runs the whole flow — important because scraped links are
   short-lived and unstable.

## Getting Started

```bash
flutter pub get
flutter run
```

Point the app at your backend by editing `ApiConstants.baseUrl` in
`lib/core/constants/api_constants.dart`. The backend is expected to expose:

| Endpoint                       | Returns |
| ------------------------------ | ------- |
| `GET /episodes/latest`         | Latest episodes |
| `GET /anime/trending`          | Trending anime |
| `GET /categories`              | Category names |
| `GET /anime/{id}`              | Anime details |
| `GET /anime/{id}/episodes`     | Episode list |
| `GET /stream/{episodeId}`      | `{ url, format, headers, quality }` |
