<?php

declare(strict_types=1);

require_once dirname(__DIR__, 2) . '/middleware/auth_middleware.php';

/**
 * /api/favorites/index.php   (protected — demonstrates auth_middleware)
 *
 *   GET    → list the authenticated user's favorite anime ids
 *   POST   → add    { "anime_id": "..." }
 *   DELETE → remove { "anime_id": "..." }  (or ?anime_id=...)
 *
 * Per the schema, only the external `anime_id` is stored. The client hydrates
 * full anime metadata (title/cover/…) from the catalog endpoints using these
 * ids. (To return full cards directly, denormalize title/cover into this
 * table — see README.)
 */

$userId = require_auth();
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

try {
    switch ($method) {
        case 'GET':
            $stmt = db()->prepare(
                'SELECT anime_id, created_at
                   FROM favorites
                  WHERE user_id = :uid
               ORDER BY created_at DESC'
            );
            $stmt->execute([':uid' => $userId]);
            Response::success($stmt->fetchAll());
            break;

        case 'POST':
            $animeId = read_anime_id();
            // INSERT ... ON DUPLICATE KEY makes "add" idempotent (the UNIQUE
            // key on (user_id, anime_id) prevents duplicates).
            $stmt = db()->prepare(
                'INSERT INTO favorites (user_id, anime_id)
                 VALUES (:uid, :aid)
                 ON DUPLICATE KEY UPDATE anime_id = anime_id'
            );
            $stmt->execute([':uid' => $userId, ':aid' => $animeId]);
            Response::success(['anime_id' => $animeId], 201);
            break;

        case 'DELETE':
            $animeId = read_anime_id();
            $stmt = db()->prepare(
                'DELETE FROM favorites WHERE user_id = :uid AND anime_id = :aid'
            );
            $stmt->execute([':uid' => $userId, ':aid' => $animeId]);
            Response::success(['anime_id' => $animeId, 'removed' => $stmt->rowCount() > 0]);
            break;

        default:
            Response::error('Method not allowed.', 405);
    }
} catch (Throwable $e) {
    error_log('favorites/index.php: ' . $e->getMessage());
    Response::error('Unexpected server error.', 500);
}

/**
 * Reads and validates the anime_id from the JSON body or the query string.
 */
function read_anime_id(): string
{
    $body    = Response::jsonBody();
    $animeId = trim((string) ($body['anime_id'] ?? $_GET['anime_id'] ?? ''));
    if ($animeId === '' || strlen($animeId) > 64) {
        Response::error('A valid anime_id is required.', 422);
    }
    return $animeId;
}
