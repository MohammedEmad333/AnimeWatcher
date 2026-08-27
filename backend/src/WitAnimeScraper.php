<?php

declare(strict_types=1);

/**
 * WitAnimeScraper — resolves episode sources for WitAnime-style watch pages
 * whose URLs follow `{base}/episode/{slug}-الحلقة-{n}/`.
 *
 * Unlike ScraperService::scrapeArabicSources(), which appends a raw episodeId
 * to the base, this builder assembles the episode path itself from a slug and
 * an episode number.
 */
class WitAnimeScraper
{
    private string $baseUrl;

    public function __construct(string $baseUrl = 'https://witanime.pics')
    {
        $this->baseUrl = rtrim($baseUrl, '/');
    }

    public function getEpisodeSources(string $animeSlug, int $episodeNumber): array
    {
        // 1. تركيب رابط الحلقة الصحيح
        $targetUrl = sprintf(
            '%s/episode/%s-%s-%d/',
            $this->baseUrl,
            $animeSlug,
            rawurlencode('الحلقة'),
            $episodeNumber
        );

        // 2. إرسال الطلب باستخدام cURL وترويسات متصفح عادي
        $ch = curl_init();
        curl_setopt_array($ch, [
            CURLOPT_URL => $targetUrl,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_FOLLOWLOCATION => true,
            CURLOPT_TIMEOUT => 10,
            CURLOPT_USERAGENT => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            CURLOPT_HTTPHEADER => [
                'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                'Accept-Language: ar,en-US;q=0.9,en;q=0.8',
            ],
        ]);

        $html = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($httpCode !== 200 || empty($html)) {
            return [];
        }

        // 3. تحليل الـ DOM واستخراج الـ iframes
        return $this->parseSourcesFromHtml($html);
    }

    private function parseSourcesFromHtml(string $html): array
    {
        $sources = [];
        $dom = new DOMDocument();
        @$dom->loadHTML('<?xml encoding="UTF-8">' . $html);
        $xpath = new DOMXPath($dom);

        // استخراج أوساط التشغيل (iframes) أو أزرار السيرفرات
        $iframes = $xpath->query('//iframe[@src]');
        foreach ($iframes as $iframe) {
            $src = $iframe->getAttribute('src');
            if (!empty($src)) {
                $sources[] = [
                    'server'  => parse_url($src, PHP_URL_HOST) ?? 'Unknown',
                    'url'     => str_starts_with($src, '//') ? 'https:' . $src : $src,
                    'quality' => 'auto',
                    'format'  => str_contains($src, '.m3u8') ? 'hls' : 'embed',
                    // Many embed hosts / CDNs reject requests without a Referer
                    // from the origin site; forward it so better_player can play.
                    'headers' => ['Referer' => $this->baseUrl . '/'],
                ];
            }
        }

        return $sources;
    }
}
