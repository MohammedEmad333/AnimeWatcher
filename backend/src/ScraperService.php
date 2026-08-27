<?php

declare(strict_types=1);

/**
 * ScraperService — resolves playable video sources for an episode.
 * ----------------------------------------------------------------
 * This is the modular seam where AnimeWatcher turns an internal `episode_id`
 * into one or more direct, playable links (progressive `.mp4` or HLS `.m3u8`).
 *
 * Each per-server `scrapeFrom*()` method is a self-contained seam you can
 * implement against one source without touching the rest
 * of the app. Until a real resolver is wired up, they return null, so
 * getSources() yields an empty array — reported by the endpoint as HTTP 200
 * with `sources: []` and rendered by the Flutter player as a clean
 * "No streaming sources available" state. Register a new server by adding it to
 * `$this->servers` and writing its `scrape*` method.
 *
 * Return contract — every source is an associative array shaped for the Flutter
 * `StreamLink` model:
 *   [
 *     'server'  => 'Server label',   // shown in a quality/server picker
 *     'url'     => 'https://…/x.m3u8',
 *     'format'  => 'hls' | 'mp4' | 'embed', // player picks HLS vs progressive
 *     'quality' => '1080p' | 'auto', // label; 'auto' for adaptive HLS
 *     'headers' => ['Referer' => '…'],// headers the player must forward to CDN
 *   ]
 */
final class ScraperService
{
    /**
     * Registry of known upstream servers, in preference order. Each maps to a
     * `scrapeFrom*` method. To add a real target, append its key + label here
     * and implement the matching method below.
     *
     * @var array<string,string> serverKey => human label
     */
    private array $servers = [
        'vidstream' => 'VidStream',
        'mp4upload' => 'MP4Upload',
    ];

    /**
     * Resolves every available source for an episode in the requested language.
     *
     * For Arabic (`lang === 'ar'`) the request is routed through the generic
     * {@see self::scrapeArabicSources()} pipeline, which fetches and parses a
     * configured watch page. English/other languages fall back to the
     * per-server resolver registry.
     *
     * @param  string $episodeId Internal episode id, e.g. "21-1" (anime 21, ep 1).
     * @param  string $lang      'ar' or 'en' — which dub/sub servers to resolve.
     * @return array<int,array<string,mixed>> Ordered list of source descriptors.
     */
    public function getSources(string $episodeId, string $lang): array
    {
        if ($lang === 'ar') {
            return $this->scrapeArabicSources($episodeId);
        }

        $sources = [];

        foreach ($this->servers as $key => $label) {
            $source = match ($key) {
                'vidstream' => $this->scrapeFromVidstream($episodeId, $lang),
                'mp4upload' => $this->scrapeFromMp4Upload($episodeId, $lang),
                default     => null,
            };
            if ($source !== null) {
                $sources[] = $source;
            }
        }

        return $sources;
    }

    // -------------------------------------------------------------------------
    // Arabic source pipeline  (generic fetch → parse → extract → normalize)
    // -------------------------------------------------------------------------

    /**
     * Resolves Arabic video sources for an episode by fetching a configured
     * watch page and extracting every embed / stream URL it exposes.
     *
     * IMPORTANT — configure your own source. It reads a base URL from the `ARABIC_SOURCE_BASE_URL`
     * environment variable (see backend/config/config.php's env() helper) and
     * builds the watch URL as `{base}/{episodeId}`. When the variable is unset the
     * method returns an empty array, so the endpoint stays a clean HTTP 200 with
     * `sources: []`.
     *
     * Pipeline:
     *   1. Build the watch URL from config + $episodeId.
     *   2. GET it via cURL with browser-like headers (User-Agent/Accept/Referer).
     *   3. Parse the HTML with DOMDocument + DOMXPath.
     *   4. Extract:
     *        - <iframe src> embed players,
     *        - <video>/<source src> direct media,
     *        - .m3u8 / .mp4 URLs referenced from inline <script> JS.
     *   5. Resolve relative URLs to absolute HTTPS against the watch URL.
     *   6. Normalize into the StreamLink contract and de-duplicate.
     *
     * All network + parsing work is wrapped so any failure yields `[]` rather
     * than a 5xx — the client simply sees "no sources".
     *
     * @return array<int,array<string,mixed>>
     */
    public function scrapeArabicSources(string $episodeId): array
    {
        $episodeId = trim($episodeId);
        if ($episodeId === '') {
            return [];
        }

        $base = env('ARABIC_SOURCE_BASE_URL');
        if ($base === null || $base === '') {
            // No source configured — nothing to scrape.
            return [];
        }

        $watchUrl = rtrim($base, '/') . '/' . rawurlencode($episodeId);

        try {
            $referer = $this->originOf($watchUrl) ?? $base;
            $html = $this->httpGet($watchUrl, [
                'Accept'  => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                'Referer' => $referer,
            ]);
        } catch (Throwable $e) {
            // Transport error / non-2xx — treat as "no sources", but keep it
            // observable server-side.
            error_log('scrapeArabicSources: fetch failed for ' . $watchUrl . ': ' . $e->getMessage());
            return [];
        }

        try {
            $sources = array_merge(
                $this->extractIframeSources($html, $watchUrl),
                $this->extractMediaSources($html, $watchUrl),
                $this->extractStreamUrlsFromScripts($html, $watchUrl),
            );

            return $this->dedupeSources($sources);
        } catch (Throwable $e) {
            error_log('scrapeArabicSources: parse failed for ' . $watchUrl . ': ' . $e->getMessage());
            return [];
        }
    }

    /**
     * Extracts embed players from <iframe src="…"> elements.
     *
     * @return array<int,array<string,mixed>>
     */
    private function extractIframeSources(string $html, string $baseUrl): array
    {
        $xp = $this->xpath($html);
        if ($xp === null) {
            return [];
        }

        $out = [];
        foreach ($xp->query('//iframe[@src]') as $iframe) {
            /** @var \DOMElement $iframe */
            $raw = trim($iframe->getAttribute('src'));
            $url = $this->resolveUrl($raw, $baseUrl);
            if ($url === null) {
                continue;
            }

            $out[] = [
                'server'  => $this->serverLabelFor($url),
                'url'     => $url,
                'format'  => $this->detectFormat($url),
                'quality' => $this->guessQuality($url),
                'headers' => ['Referer' => $this->originOf($baseUrl) ?? $baseUrl],
            ];
        }

        return $out;
    }

    /**
     * Extracts direct media from <video src> and nested <source src> tags.
     *
     * @return array<int,array<string,mixed>>
     */
    private function extractMediaSources(string $html, string $baseUrl): array
    {
        $xp = $this->xpath($html);
        if ($xp === null) {
            return [];
        }

        $out = [];
        foreach ($xp->query('//video[@src] | //video/source[@src] | //source[@src]') as $node) {
            /** @var \DOMElement $node */
            $raw = trim($node->getAttribute('src'));
            $url = $this->resolveUrl($raw, $baseUrl);
            if ($url === null) {
                continue;
            }

            // Prefer an explicit label/size/res attribute when the markup carries one.
            $quality = $node->getAttribute('data-quality')
                ?: $node->getAttribute('label')
                ?: $node->getAttribute('size')
                ?: $node->getAttribute('res')
                ?: $this->guessQuality($url);

            $out[] = [
                'server'  => $this->serverLabelFor($url),
                'url'     => $url,
                'format'  => $this->detectFormat($url),
                'quality' => $this->normalizeQuality((string) $quality) ?? $this->guessQuality($url),
                'headers' => ['Referer' => $this->originOf($baseUrl) ?? $baseUrl],
            ];
        }

        return $out;
    }

    /**
     * Extracts `.m3u8` / `.mp4` URLs referenced from inline <script> JS — the
     * common case where players are configured from a packed `sources: [...]`
     * or `"file":"…"` blob rather than plain <video> markup.
     *
     * @return array<int,array<string,mixed>>
     */
    private function extractStreamUrlsFromScripts(string $html, string $baseUrl): array
    {
        // Unescape common JS/JSON slash escaping first ("https:\/\/…" → "https://")
        // so escaped URLs match as a whole instead of being split at a backslash.
        $scan = str_replace('\\/', '/', $html);

        // Match absolute or root/relative URLs ending in .m3u8 or .mp4, with an
        // optional query string, as they appear inside quotes in JS/JSON.
        $pattern = '#(?:https?:)?//[^\s"\'\\\\<>()]+?\.(?:m3u8|mp4)(?:\?[^\s"\'\\\\<>()]*)?'
                 . '|(?<![\w.])/[^\s"\'\\\\<>()]+?\.(?:m3u8|mp4)(?:\?[^\s"\'\\\\<>()]*)?#i';

        if (!preg_match_all($pattern, $scan, $matches)) {
            return [];
        }

        $out = [];
        foreach ($matches[0] as $raw) {
            $url = $this->resolveUrl(trim($raw), $baseUrl);
            if ($url === null) {
                continue;
            }

            $out[] = [
                'server'  => $this->serverLabelFor($url),
                'url'     => $url,
                'format'  => $this->detectFormat($url),
                'quality' => $this->guessQuality($url),
                'headers' => ['Referer' => $this->originOf($baseUrl) ?? $baseUrl],
            ];
        }

        return $out;
    }

    // -------------------------------------------------------------------------
    // Per-server resolvers  (⇩ inject real DOM/JSON parsing here ⇩)
    // -------------------------------------------------------------------------

    /**
     * Resolve an HLS (`.m3u8`) source. Placeholder returns null until a real,
     * resolver is wired up (see scrapeArabicSources for the pattern).
     *
     * @return array<string,mixed>|null
     */
    private function scrapeFromVidstream(string $episodeId, string $lang): ?array
    {
        return null;
    }

    /**
     * Resolve a progressive MP4 source. Placeholder returns null until a real,
     * resolver is wired up (see scrapeArabicSources for the pattern).
     *
     * @return array<string,mixed>|null
     */
    private function scrapeFromMp4Upload(string $episodeId, string $lang): ?array
    {
        return null;
    }

    // -------------------------------------------------------------------------
    // Parsing / normalization helpers
    // -------------------------------------------------------------------------

    /**
     * Builds a DOMXPath over the given HTML, or null if it can't be parsed.
     * libxml errors are captured (not emitted) so malformed markup never warns.
     */
    private function xpath(string $html): ?DOMXPath
    {
        if (trim($html) === '') {
            return null;
        }

        $previous = libxml_use_internal_errors(true);
        try {
            $dom = new DOMDocument();
            // Hint UTF-8 so Arabic text nodes/attributes decode correctly.
            $loaded = $dom->loadHTML(
                '<?xml encoding="UTF-8">' . $html,
                LIBXML_NOWARNING | LIBXML_NOERROR
            );
            if ($loaded === false) {
                return null;
            }
            return new DOMXPath($dom);
        } finally {
            libxml_clear_errors();
            libxml_use_internal_errors($previous);
        }
    }

    /**
     * Resolves a possibly-relative URL to an absolute HTTPS URL against $baseUrl.
     * Returns null for non-http(s) schemes (data:, javascript:, about:blank, …)
     * and for anything that can't be resolved to a host.
     */
    private function resolveUrl(string $url, string $baseUrl): ?string
    {
        $url = trim($url);
        if ($url === '' || $url === '#' || str_starts_with($url, 'about:')) {
            return null;
        }

        // Reject non-navigational schemes outright.
        if (preg_match('#^(data|javascript|blob|mailto|tel):#i', $url)) {
            return null;
        }

        // Protocol-relative → force https.
        if (str_starts_with($url, '//')) {
            return 'https:' . $url;
        }

        // Already absolute http(s): upgrade http → https for playback.
        if (preg_match('#^https?://#i', $url)) {
            return preg_replace('#^http://#i', 'https://', $url);
        }

        // Relative — resolve against the base URL's origin + path.
        $parts = parse_url($baseUrl);
        if ($parts === false || empty($parts['host'])) {
            return null;
        }
        $origin = 'https://' . $parts['host'] . (isset($parts['port']) ? ':' . $parts['port'] : '');

        if (str_starts_with($url, '/')) {
            return $origin . $url;
        }

        // Path-relative: resolve against the directory of the base path.
        $dir = isset($parts['path']) ? preg_replace('#/[^/]*$#', '/', $parts['path']) : '/';
        if ($dir === '' || $dir === null) {
            $dir = '/';
        }
        return $origin . $dir . $url;
    }

    /**
     * Returns the scheme+host(+port) origin of a URL, or null if it has no host.
     */
    private function originOf(string $url): ?string
    {
        $parts = parse_url($url);
        if ($parts === false || empty($parts['host'])) {
            return null;
        }
        $scheme = $parts['scheme'] ?? 'https';
        $port   = isset($parts['port']) ? ':' . $parts['port'] : '';
        return $scheme . '://' . $parts['host'] . $port;
    }

    /**
     * Classifies a URL into the player's format contract.
     *   .m3u8 → 'hls', .mp4 → 'mp4', anything else (iframe embeds) → 'embed'.
     */
    private function detectFormat(string $url): string
    {
        $path = strtolower((string) parse_url($url, PHP_URL_PATH));
        if (str_contains($path, '.m3u8')) {
            return 'hls';
        }
        if (str_contains($path, '.mp4')) {
            return 'mp4';
        }
        return 'embed';
    }

    /**
     * Best-effort quality label from a URL. HLS manifests are adaptive → 'auto';
     * otherwise sniff a "1080p"/"720"/… token from the path/query.
     */
    private function guessQuality(string $url): string
    {
        if ($this->detectFormat($url) === 'hls') {
            return 'auto';
        }
        if (preg_match('#(\d{3,4})\s*p?\b#i', $url, $m)) {
            $normalized = $this->normalizeQuality($m[1]);
            if ($normalized !== null) {
                return $normalized;
            }
        }
        return 'auto';
    }

    /**
     * Normalizes a raw quality token ("1080", "1080p", "HD", "auto") to a
     * canonical label, or null if it isn't a recognizable resolution.
     */
    private function normalizeQuality(string $raw): ?string
    {
        $raw = strtolower(trim($raw));
        if ($raw === 'auto' || $raw === 'hd' || $raw === 'sd') {
            return $raw === 'auto' ? 'auto' : $raw;
        }
        if (preg_match('#(\d{3,4})#', $raw, $m)) {
            $n = (int) $m[1];
            if ($n >= 144 && $n <= 4320) {
                return $n . 'p';
            }
        }
        return null;
    }

    /**
     * Derives a human-friendly server label from the URL host (e.g.
     * "cdn.example.com" → "Example"), falling back to "Direct" when hostless.
     */
    private function serverLabelFor(string $url): string
    {
        $host = parse_url($url, PHP_URL_HOST);
        if (!is_string($host) || $host === '') {
            return 'Direct';
        }

        // Strip common CDN/subdomain noise, then take the registrable label.
        $host = preg_replace('#^(www|cdn|embed|stream|player|video|v\d*)\.#i', '', $host);
        $labels = explode('.', (string) $host);
        $name = $labels[0] ?? $host;

        return ucfirst($name);
    }

    /**
     * De-duplicates sources by normalized URL, preserving first-seen order.
     *
     * @param  array<int,array<string,mixed>> $sources
     * @return array<int,array<string,mixed>>
     */
    private function dedupeSources(array $sources): array
    {
        $seen = [];
        $out = [];
        foreach ($sources as $source) {
            $url = (string) ($source['url'] ?? '');
            if ($url === '') {
                continue;
            }
            $key = rtrim($url, '/');
            if (isset($seen[$key])) {
                continue;
            }
            $seen[$key] = true;
            $out[] = $source;
        }
        return $out;
    }

    // -------------------------------------------------------------------------
    // Shared HTTP helper for real scrapers (kept here so resolvers stay small).
    // -------------------------------------------------------------------------

    /**
     * Fetches a URL over cURL with sane, browser-like defaults, returning the
     * response body. Real resolvers should route requests through this so
     * timeouts, redirects and headers stay consistent.
     *
     * @param  array<string,string> $headers Extra request headers (e.g. Referer).
     * @throws RuntimeException on transport error or non-2xx status.
     */
    private function httpGet(string $url, array $headers = []): string
    {
        if (!function_exists('curl_init')) {
            throw new RuntimeException('cURL extension is required for scraping.');
        }

        // Browser-like defaults; callers can override any of these via $headers.
        $defaults = [
            'User-Agent'      => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
                . 'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
            'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language' => 'ar,en;q=0.8',
        ];
        $merged = array_merge($defaults, $headers);

        $headerLines = [];
        foreach ($merged as $name => $value) {
            $headerLines[] = "$name: $value";
        }

        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_FOLLOWLOCATION => true,
            CURLOPT_MAXREDIRS      => 5,
            CURLOPT_CONNECTTIMEOUT => 8,
            CURLOPT_TIMEOUT        => 10,
            CURLOPT_HTTPHEADER     => $headerLines,
            CURLOPT_ENCODING       => '', // accept gzip/deflate transparently
        ]);

        $body   = curl_exec($ch);
        $errNo  = curl_errno($ch);
        $status = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $errMsg = curl_error($ch);
        curl_close($ch);

        if ($errNo !== 0 || $body === false) {
            throw new RuntimeException("Scrape request failed: $errMsg");
        }
        if ($status < 200 || $status >= 300) {
            throw new RuntimeException("Scrape target returned HTTP $status.");
        }

        return (string) $body;
    }
}
