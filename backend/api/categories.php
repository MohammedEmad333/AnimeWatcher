<?php

declare(strict_types=1);

require_once dirname(__DIR__) . '/src/bootstrap.php';
require_once dirname(__DIR__) . '/src/JikanClient.php';

/**
 * GET /api/categories   (public)
 *
 * Proxies + caches Jikan's anime genres feed for the home screen's category
 * chips. Returns a list of normalized rows:
 *   [{ id, name, count }]
 */

Response::requireMethod('GET');

try {
    $items = (new JikanClient())->getCategories();
    Response::success($items);
} catch (Throwable $e) {
    error_log('categories.php: ' . $e->getMessage());
    // 502: we're a gateway and the upstream catalog service failed.
    Response::error('Could not load categories right now.', 502);
}
