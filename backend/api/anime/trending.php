<?php

declare(strict_types=1);

require_once dirname(__DIR__, 2) . '/src/bootstrap.php';
require_once dirname(__DIR__, 2) . '/src/JikanClient.php';

/**
 * GET /api/anime/trending[?limit=20]   (public)
 *
 * Proxies + caches the Jikan API's popular-anime feed for the home screen.
 * Returns a list of normalized Anime rows:
 *   [{ id, title, cover_url, synopsis, rating, genres[], episode_count }]
 */

Response::requireMethod('GET');

$limit = (int) ($_GET['limit'] ?? 20);

try {
    $items = (new JikanClient())->getTrending($limit);
    Response::success($items);
} catch (Throwable $e) {
    error_log('anime/trending.php: ' . $e->getMessage());
    // 502: we're a gateway and the upstream catalog service failed.
    Response::error('Could not load trending anime right now.', 502);
}
