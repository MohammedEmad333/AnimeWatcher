<?php

declare(strict_types=1);

/**
 * Thin proxy + cache in front of the public Jikan API (MyAnimeList).
 * ------------------------------------------------------------------
 * Jikan is unauthenticated but rate-limited, so we cache every upstream
 * response on disk for a configurable TTL. Cached hits are served without
 * touching the network, which keeps the home screen fast and stays well
 * under Jikan's rate limits.
 *
 * Responses are normalized into the exact shape the Flutter `Anime` model
 * expects: { id, title, cover_url, synopsis, rating, genres[], episode_count }.
 *
 * Config (see .env / .env.example):
 *   JIKAN_BASE_URL   default https://api.jikan.moe/v4
 *   CACHE_DIR        default <backend>/cache
 *   CACHE_TTL        default 21600 (6h) — upstream cache lifetime in seconds
 */
final class JikanClient
{
    private string $baseUrl;
    private string $cacheDir;
    private int $ttl;

    public function __construct()
    {
        $this->baseUrl  = rtrim(env('JIKAN_BASE_URL', 'https://api.jikan.moe/v4') ?? '', '/');
        $this->cacheDir = rtrim(env('CACHE_DIR', dirname(__DIR__) . '/cache') ?? '', '/');
        $this->ttl      = (int) (env('CACHE_TTL', '21600') ?? '21600');

        if (!is_dir($this->cacheDir)) {
            @mkdir($this->cacheDir, 0775, true);
        }
    }

    /**
     * Trending / most popular titles for the home screen.
     *
     * @param  int $limit 1–25 (Jikan page size cap).
     * @return array<int,array<string,mixed>> Normalized Anime rows.
     */
    public function getTrending(int $limit = 20): array
    {
        $limit = max(1, min($limit, 25));
        $json  = $this->get('/top/anime', ['filter' => 'bypopularity', 'limit' => $limit]);

        $items = $json['data'] ?? [];
        return array_map([$this, 'mapAnime'], is_array($items) ? $items : []);
    }

    /**
     * Full details for a single anime by MyAnimeList id.
     *
     * @return array<string,mixed>|null Normalized Anime row, or null if unknown.
     */
    public function getDetails(int $malId): ?array
    {
        $json = $this->get('/anime/' . $malId . '/full');
        $data = $json['data'] ?? null;
        return is_array($data) ? $this->mapAnime($data) : null;
    }

    // -------------------------------------------------------------------------
    // HTTP + cache
    // -------------------------------------------------------------------------

    /**
     * GETs a Jikan endpoint (with query params), returning the decoded JSON.
     * Served from disk cache when a fresh copy exists.
     *
     * @param  array<string,scalar> $query
     * @return array<string,mixed>
     */
    private function get(string $path, array $query = []): array
    {
        $url = $this->baseUrl . $path;
        if ($query !== []) {
            $url .= '?' . http_build_query($query);
        }

        $cached = $this->readCache($url);
        if ($cached !== null) {
            return $cached;
        }

        $body = $this->fetch($url);
        $decoded = json_decode($body, true);
        if (!is_array($decoded)) {
            throw new RuntimeException('Malformed response from upstream catalog service.');
        }

        $this->writeCache($url, $decoded);
        return $decoded;
    }

    /**
     * Performs the actual network request via cURL.
     * Throws a RuntimeException on transport or non-2xx errors.
     */
    private function fetch(string $url): string
    {
        if (!function_exists('curl_init')) {
            throw new RuntimeException('cURL extension is required to reach the catalog service.');
        }

        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_FOLLOWLOCATION => true,
            CURLOPT_CONNECTTIMEOUT => 8,
            CURLOPT_TIMEOUT        => 15,
            CURLOPT_HTTPHEADER     => ['Accept: application/json'],
            CURLOPT_USERAGENT      => 'AnimeWatcher/1.0 (+catalog-proxy)',
        ]);

        $body   = curl_exec($ch);
        $errNo  = curl_errno($ch);
        $status = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $errMsg = curl_error($ch);
        curl_close($ch);

        if ($errNo !== 0 || $body === false) {
            throw new RuntimeException('Catalog service is unreachable: ' . $errMsg);
        }
        if ($status < 200 || $status >= 300) {
            throw new RuntimeException("Catalog service returned HTTP $status.");
        }

        return (string) $body;
    }

    /**
     * Returns the cached, still-fresh payload for $url, or null on miss/expiry.
     *
     * @return array<string,mixed>|null
     */
    private function readCache(string $url): ?array
    {
        $file = $this->cacheFile($url);
        if (!is_file($file)) {
            return null;
        }
        if ((time() - filemtime($file)) > $this->ttl) {
            return null; // stale
        }
        $raw = file_get_contents($file);
        if ($raw === false) {
            return null;
        }
        $decoded = json_decode($raw, true);
        return is_array($decoded) ? $decoded : null;
    }

    /**
     * Persists a decoded payload to the cache (best-effort; never fatal).
     *
     * @param array<string,mixed> $payload
     */
    private function writeCache(string $url, array $payload): void
    {
        $file = $this->cacheFile($url);
        @file_put_contents(
            $file,
            json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE),
            LOCK_EX
        );
    }

    private function cacheFile(string $url): string
    {
        return $this->cacheDir . '/jikan_' . sha1($url) . '.json';
    }

    // -------------------------------------------------------------------------
    // Normalization
    // -------------------------------------------------------------------------

    /**
     * Maps a raw Jikan anime object into the app's flat Anime shape.
     *
     * @param  array<string,mixed> $a
     * @return array<string,mixed>
     */
    private function mapAnime(array $a): array
    {
        $images = $a['images']['jpg'] ?? [];
        $cover  = $images['large_image_url']
            ?? $images['image_url']
            ?? '';

        $genres = [];
        foreach (($a['genres'] ?? []) as $g) {
            if (isset($g['name'])) {
                $genres[] = (string) $g['name'];
            }
        }

        return [
            'id'            => (string) ($a['mal_id'] ?? ''),
            'title'         => (string) ($a['title_english'] ?? $a['title'] ?? ''),
            'cover_url'     => (string) $cover,
            'synopsis'      => (string) ($a['synopsis'] ?? ''),
            'rating'        => (float) ($a['score'] ?? 0),
            'genres'        => $genres,
            'episode_count' => (int) ($a['episodes'] ?? 0),
        ];
    }
}
