<?php

declare(strict_types=1);

require_once dirname(__DIR__, 2) . '/src/bootstrap.php';
require_once dirname(__DIR__, 2) . '/src/ScraperService.php';

/**
 * GET /api/episodes/sources?episode_id={id}&lang={ar|en}   (public)
 *
 * Resolves the direct, playable video sources for an episode via the modular
 * ScraperService. Currently returns mock `.mp4` / `.m3u8` links (see
 * src/ScraperService.php for where to inject real DOM/JSON parsing).
 *
 * Response:
 *   {
 *     "episode_id": "21-1",
 *     "lang": "en",
 *     "sources": [
 *       { "server", "url", "format": "hls"|"mp4", "quality", "headers": {} },
 *       ...
 *     ]
 *   }
 *
 * The list is ordered by server preference, so a client that only wants one
 * link can simply take `sources[0]`.
 */

Response::requireMethod('GET');

$episodeId = trim((string) ($_GET['episode_id'] ?? ''));
if ($episodeId === '' || strlen($episodeId) > 64) {
    Response::error('A valid episode_id is required.', 422);
}

// Language selects which dub/sub servers to resolve; default to Arabic to match
// the app's default content language. Anything unrecognized falls back to 'ar'.
$lang = strtolower(trim((string) ($_GET['lang'] ?? 'ar')));
if (!in_array($lang, ['ar', 'en'], true)) {
    $lang = 'ar';
}

try {
    $sources = (new ScraperService())->getSources($episodeId, $lang);

    if ($sources === []) {
        Response::error('No playable sources were found for this episode.', 404);
    }

    Response::success([
        'episode_id' => $episodeId,
        'lang'       => $lang,
        'sources'    => $sources,
    ]);
} catch (Throwable $e) {
    error_log('episodes/sources.php: ' . $e->getMessage());
    Response::error('Could not resolve video sources right now.', 502);
}
