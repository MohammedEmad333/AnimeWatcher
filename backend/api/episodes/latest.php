<?php

declare(strict_types=1);

require_once dirname(__DIR__, 2) . '/src/bootstrap.php';
require_once dirname(__DIR__, 2) . '/src/JikanClient.php';

/**
 * GET /api/episodes/latest[?limit=20]   (public)
 *
 * Proxies + caches Jikan's "recently aired episodes" feed for the home screen.
 * Returns a list of normalized Episode rows:
 *   [{ id, anime_id, number, title, thumbnail_url }]
 */

Response::requireMethod('GET');

$limit = (int) ($_GET['limit'] ?? 20);

try {
    $items = (new JikanClient())->getLatestEpisodes($limit);
    Response::success($items);
} catch (Throwable $e) {
    error_log('episodes/latest.php: ' . $e->getMessage());
    // 502: we're a gateway and the upstream catalog service failed.
    Response::error('Could not load the latest episodes right now.', 502);
}
