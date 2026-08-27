# AnimeWatcher — Backend API

Plain-PHP (no framework) + MySQL backend providing JWT authentication and
cloud sync (favorites, watch history) for the AnimeWatcher Flutter app.

## Requirements

- PHP 8.1+ (uses `never` return types, `str_starts_with`, etc.)
- MySQL 5.7+ / MariaDB 10.2+
- PDO MySQL extension

No Composer packages are required — the JWT handler is self-contained
(`src/Jwt.php`). `firebase/php-jwt` is a documented optional drop-in.

## Setup

```bash
# 1. Create the database + tables
mysql -u root -p < schema.sql

# 2. Configure environment
cp .env.example .env
#    then edit .env — at minimum set DB creds and a strong JWT_SECRET:
#    openssl rand -hex 32

# 3. Serve (dev). Point the doc root at the backend/ folder.
php -S localhost:8000
```

The Flutter client's `ApiConstants.baseUrl` should point at this host (e.g.
`http://10.0.2.2:8000/api` from the Android emulator).

### Clean URLs (front controller)

All traffic under `/api/*` is routed through a single front controller
(`api/index.php`) by `.htaccess`, so endpoints have clean, extension-less URLs
(`POST /api/auth/login`, `GET /api/anime/details/21`). CORS headers, `OPTIONS`
preflight and the JWT middleware are applied uniformly for every routed
endpoint. The underlying `.php` files remain individually addressable too (the
rewrite only kicks in when a request doesn't map to a real file), so nothing
that worked before is broken.

> Apache's built-in dev server (`php -S`) ignores `.htaccess`. To exercise the
> clean URLs locally, run the front controller as the router script:
>
> ```bash
> php -S localhost:8000 api/index.php
> ```

## Directory structure

```text
backend/
├── schema.sql                 # Database + tables (users, favorites, watch_history)
├── .env.example               # Copy to .env (DB creds, JWT secret, CORS)
├── .htaccess                  # Forwards Authorization header; denies .env
├── composer.json              # Optional; documents firebase/php-jwt
│
├── config/
│   ├── config.php             # env() loader (.env + process env)
│   ├── database.php           # PDO factory (prepared statements, utf8mb4)
│   └── cors.php               # CORS + JSON headers, preflight handling
│
├── src/
│   ├── bootstrap.php          # One include: config + db + jwt + response + CORS
│   ├── Jwt.php                # HS256 encode/verify (constant-time)
│   ├── Response.php           # JSON envelope + input helpers
│   ├── JikanClient.php        # Jikan (MyAnimeList) proxy + disk cache
│   └── ScraperService.php     # Modular video-source resolver (mock + real hooks)
│
├── middleware/
│   └── auth_middleware.php    # require_auth(): validates Bearer JWT → user id
│
├── cache/                     # Cached Jikan responses (gitignored, auto-created)
│
├── api/
│   ├── index.php              # Front controller / router (clean URLs)
│   ├── auth/
│   │   ├── register.php       # POST  create user, hash password, issue JWT
│   │   ├── login.php          # POST  verify credentials, issue JWT
│   │   ├── logout.php         # POST  (protected) acknowledge logout
│   │   └── me.php             # GET   (protected) current user
│   ├── anime/
│   │   ├── trending.php       # GET   popular titles (Jikan proxy + cache)
│   │   └── details.php        # GET   one title by id (Jikan proxy + cache)
│   ├── episodes/
│   │   └── sources.php        # GET   scraped video sources for an episode
│   ├── favorites/
│   │   └── index.php          # GET/POST/DELETE (protected) — uses middleware
│   └── history/
│       └── index.php          # GET/POST (protected) resume positions
│
└── tests/
    └── jwt_test.php           # Standalone JWT sanity checks (no DB needed)
```

## Response envelope

Every endpoint returns JSON in a consistent shape:

```jsonc
// success
{ "success": true, "data": { /* ... */ } }
// error
{ "success": false, "message": "…", "errors": { "field": "…" } }
```

Auth success payload: `{ "token": "<jwt>", "user": { "id", "name", "email" } }`.

## Endpoints

| Method | Path                        | Auth | Body |
| ------ | --------------------------- | ---- | ---- |
| POST   | `/api/auth/register`        | —    | `{ name, email, password }` |
| POST   | `/api/auth/login`           | —    | `{ email, password }` |
| POST   | `/api/auth/logout`          | ✔    | — |
| GET    | `/api/auth/me`              | ✔    | — |
| GET    | `/api/anime/trending?limit=20` | — | — (Jikan proxy + cache) |
| GET    | `/api/anime/details/{id}`   | —    | — (Jikan proxy + cache) |
| GET    | `/api/episodes/sources?episode_id=..&lang={ar\|en}` | — | — (scraped sources) |
| GET    | `/api/favorites`            | ✔    | — |
| POST   | `/api/favorites`            | ✔    | `{ anime_id, title, cover_image }` |
| DELETE | `/api/favorites`            | ✔    | `{ anime_id }` |
| GET    | `/api/history`              | ✔    | — (full history list) |
| GET    | `/api/history?anime_id=..&episode_id=..` | ✔ | — (resume position) |
| POST   | `/api/history`              | ✔    | `{ anime_id, episode_id, playback_time }` |

`✔` = requires `Authorization: Bearer <jwt>`.

### Catalog & scraping

- **`GET /api/anime/trending`** and **`GET /api/anime/details/{id}`** proxy the
  public [Jikan](https://jikan.moe) API (MyAnimeList) and cache each upstream
  response on disk (`cache/`, TTL `CACHE_TTL`, default 6h) to stay fast and
  under Jikan's rate limits. Responses are normalized to the Flutter `Anime`
  shape: `{ id, title, cover_url, synopsis, rating, genres[], episode_count }`.
- **`GET /api/episodes/sources?episode_id=..&lang=..`** returns a
  preference-ordered `sources` list from `src/ScraperService.php`
  (`{ server, url, format: hls|mp4, quality, headers }`). The service currently
  returns **mock** `.mp4` / `.m3u8` links; each per-server `scrapeFrom*()`
  method carries a commented sketch showing exactly where to inject real
  cURL + `DOMDocument`/`DOMXPath` parsing for a target site.

## Security notes

- **PDO prepared statements** everywhere; `ATTR_EMULATE_PREPARES = false`.
- Passwords hashed with `password_hash(PASSWORD_DEFAULT)`; verified with
  `password_verify`; transparently rehashed on login when the cost changes.
- **JWT** signed HS256, verified in constant time (`hash_equals`), with `exp`
  enforced. The handler refuses to sign with an unset/placeholder secret.
- Login returns the **same** error for unknown email vs. wrong password (no
  account enumeration).
- CORS origins are an allowlist (`CORS_ALLOWED_ORIGINS`); the token lives in the
  `Authorization` header (not cookies), so no `Allow-Credentials`.
- Errors are logged server-side (`error_log`) and returned to clients as
  generic messages — no stack traces or SQL leaked.

Recommended hardening for production: per-IP rate limiting on auth routes,
HTTPS only, a token denylist (`jti`) for true logout/rotation, and a shorter
access-token TTL paired with refresh tokens.

## Favorites metadata (denormalized)

`favorites` stores `title` + `cover_image` alongside `anime_id`, so
`GET /favorites` returns ready-to-render cards
(`[{ anime_id, title, cover_image, created_at }]`) with **no** second
catalog/Jikan lookup. `POST /favorites` accepts `{ anime_id, title,
cover_image }` and UPSERTs the metadata.

Existing databases: apply `migrations/001_favorites_add_metadata.sql`. Fresh
installs already include the columns via `schema.sql`.
