<?php

declare(strict_types=1);

require_once dirname(__DIR__, 2) . '/src/bootstrap.php';
require_once dirname(__DIR__, 2) . '/src/JikanClient.php';

/**
 * GET /api/anime/details/{id}   (public)
 *
 * Proxies + caches Jikan's full-details endpoint for a single title. The `{id}`
 * path segment is supplied by the router as $_GET['id'] (and also accepted as a
 * plain ?id= query param for direct-file access).
 *
 * Returns one normalized Anime row:
 *   { id, title, cover_url, synopsis, rating, genres[], episode_count }
 */

Response::requireMethod('GET');

$id = (int) trim((string) ($_GET['id'] ?? ''));
if ($id <= 0) {
    Response::error('A valid anime id is required.', 422);
}

try {
    $anime = (new JikanClient())->getDetails($id);
    if ($anime === null) {
        Response::error('Anime not found.', 404);
    }
    Response::success($anime);
} catch (Throwable $e) {
    error_log('anime/details.php: ' . $e->getMessage());
    Response::error('Could not load anime details right now.', 502);
}
