<?php

declare(strict_types=1);

/**
 * ScraperService — resolves playable video sources for an episode.
 * ----------------------------------------------------------------
 * This is the modular seam where AnimeWatcher turns an internal `episode_id`
 * into one or more direct, playable links (progressive `.mp4` or HLS `.m3u8`).
 *
 * The implementation below returns **mock** links so the whole stack (router →
 * endpoint → Flutter player) is runnable end-to-end today. Real scraping is
 * intentionally isolated behind the per-server `scrapeFrom*()` methods: each is
 * a self-contained unit you can implement against one target site without
 * touching the rest of the app. Register a new server by adding it to
 * `$this->servers` and writing its `scrape*` method.
 *
 * Return contract — every source is an associative array shaped for the Flutter
 * `StreamLink` model:
 *   [
 *     'server'  => 'Server label',   // shown in a quality/server picker
 *     'url'     => 'https://…/x.m3u8',
 *     'format'  => 'hls' | 'mp4',    // player picks HLS vs progressive
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
     * @param  string $episodeId Internal episode id, e.g. "21-1" (anime 21, ep 1).
     * @param  string $lang      'ar' or 'en' — which dub/sub servers to resolve.
     * @return array<int,array<string,mixed>> Ordered list of source descriptors.
     */
    public function getSources(string $episodeId, string $lang): array
    {
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
    // Per-server resolvers  (⇩ inject real DOM/JSON parsing here ⇩)
    // -------------------------------------------------------------------------

    /**
     * Resolve an HLS (`.m3u8`) source. Placeholder returns a mock manifest.
     *
     * REAL IMPLEMENTATION SKETCH:
     *   1. Map $episodeId → the target site's watch URL for $lang.
     *   2. $html = $this->httpGet($watchUrl, ['Referer' => $siteBase]);
     *   3. Extract the embedded player iframe / packed JS, e.g.:
     *        $dom = new DOMDocument();
     *        @$dom->loadHTML($html);
     *        $xp  = new DOMXPath($dom);
     *        $src = $xp->query('//iframe[@id="player"]')->item(0)?->getAttribute('src');
     *   4. Follow the iframe, then regex/JSON-decode the sources array to pull
     *      the `.m3u8` URL and any required Referer/User-Agent headers.
     *   5. Return them in the contract shape below (format => 'hls').
     *   Return null if this server has no source for the episode.
     *
     * @return array<string,mixed>|null
     */
    private function scrapeFromVidstream(string $episodeId, string $lang): ?array
    {
        // --- MOCK (remove once real parsing is wired up) ---------------------
        return [
            'server'  => $this->servers['vidstream'],
            'url'     => "https://cdn.example-vidstream.test/hls/{$lang}/{$episodeId}/master.m3u8",
            'format'  => 'hls',
            'quality' => 'auto',
            'headers' => ['Referer' => 'https://example-vidstream.test/'],
        ];
    }

    /**
     * Resolve a progressive MP4 source. Placeholder returns a mock file link.
     *
     * REAL IMPLEMENTATION SKETCH:
     *   1. $html = $this->httpGet($embedUrl);
     *   2. Pull the direct file, e.g. with a tolerant regex over packed JS:
     *        preg_match('#"file"\s*:\s*"([^"]+\.mp4)"#', $html, $m);
     *        $mp4 = stripslashes($m[1] ?? '');
     *   3. Return it (format => 'mp4', a concrete quality label if known).
     *   Return null if extraction fails.
     *
     * @return array<string,mixed>|null
     */
    private function scrapeFromMp4Upload(string $episodeId, string $lang): ?array
    {
        // --- MOCK (remove once real parsing is wired up) ---------------------
        return [
            'server'  => $this->servers['mp4upload'],
            'url'     => "https://cdn.example-mp4upload.test/files/{$lang}/{$episodeId}/1080p.mp4",
            'format'  => 'mp4',
            'quality' => '1080p',
            'headers' => ['Referer' => 'https://example-mp4upload.test/'],
        ];
    }

    // -------------------------------------------------------------------------
    // Shared HTTP helper for real scrapers (kept here so resolvers stay small).
    // -------------------------------------------------------------------------

    /**
     * Fetches a URL over cURL with sane defaults, returning the response body.
     * Real `scrapeFrom*` methods should route their requests through this so
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

        $headerLines = ['User-Agent: Mozilla/5.0 (AnimeWatcher scraper)'];
        foreach ($headers as $name => $value) {
            $headerLines[] = "$name: $value";
        }

        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_FOLLOWLOCATION => true,
            CURLOPT_CONNECTTIMEOUT => 8,
            CURLOPT_TIMEOUT        => 20,
            CURLOPT_HTTPHEADER     => $headerLines,
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
