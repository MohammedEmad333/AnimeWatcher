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
 * `title` + `cover_image` are stored denormalized alongside `anime_id`, so
 * GET returns ready-to-render cards with no second catalog lookup.
 */

$userId = require_auth();
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

try {
    switch ($method) {
        case 'GET':
            $stmt = db()->prepare(
                'SELECT anime_id, title, cover_image, created_at
                   FROM favorites
                  WHERE user_id = :uid
               ORDER BY created_at DESC'
            );
            $stmt->execute([':uid' => $userId]);
            Response::success($stmt->fetchAll());
            break;

        case 'POST':
            $body    = Response::jsonBody();
            $animeId = require_anime_id($body);

            // Optional display metadata (denormalized for instant rendering).
            $title = trim((string) ($body['title'] ?? ''));
            $cover = trim((string) ($body['cover_image'] ?? $body['cover_url'] ?? ''));
            $title = $title !== '' ? mb_substr($title, 0, 255) : null;
            $cover = $cover !== '' ? mb_substr($cover, 0, 512) : null;

            // INSERT ... ON DUPLICATE KEY makes "add" idempotent (the UNIQUE
            // key on (user_id, anime_id) prevents duplicates) and refreshes the
            // stored metadata.
            $stmt = db()->prepare(
                'INSERT INTO favorites (user_id, anime_id, title, cover_image)
                 VALUES (:uid, :aid, :title, :cover)
                 ON DUPLICATE KEY UPDATE
                     title       = VALUES(title),
                     cover_image = VALUES(cover_image)'
            );
            $stmt->execute([
                ':uid'   => $userId,
                ':aid'   => $animeId,
                ':title' => $title,
                ':cover' => $cover,
            ]);
            Response::success([
                'anime_id'    => $animeId,
                'title'       => $title,
                'cover_image' => $cover,
            ], 201);
            break;

        case 'DELETE':
            $animeId = require_anime_id(Response::jsonBody());
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
 * Reads and validates the anime_id from a decoded body (falling back to the
 * query string, e.g. for DELETE ?anime_id=...).
 *
 * @param array<string,mixed> $body
 */
function require_anime_id(array $body): string
{
    $animeId = trim((string) ($body['anime_id'] ?? $_GET['anime_id'] ?? ''));
    if ($animeId === '' || strlen($animeId) > 64) {
        Response::error('A valid anime_id is required.', 422);
    }
    return $animeId;
}
