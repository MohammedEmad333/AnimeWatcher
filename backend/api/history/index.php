<?php

declare(strict_types=1);

require_once dirname(__DIR__, 2) . '/middleware/auth_middleware.php';

/**
 * /api/history/index.php   (protected)
 *
 *   GET  → list the user's watch history (most recently updated first)
 *   GET ?anime_id=..&episode_id=..
 *        → resume position for one episode: { playback_time } (0 if none)
 *   POST → upsert resume position
 *          { "anime_id": "...", "episode_id": "...", "playback_time": 123 }
 *
 * The UNIQUE key on (user_id, anime_id, episode_id) lets POST UPSERT the
 * playback_time so the client can resume an episode where it left off.
 */

$userId = require_auth();
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

try {
    if ($method === 'GET') {
        $animeId   = trim((string) ($_GET['anime_id'] ?? ''));
        $episodeId = trim((string) ($_GET['episode_id'] ?? ''));

        // Single-episode resume lookup.
        if ($animeId !== '' && $episodeId !== '') {
            $stmt = db()->prepare(
                'SELECT playback_time, updated_at
                   FROM watch_history
                  WHERE user_id = :uid AND anime_id = :aid AND episode_id = :eid
                  LIMIT 1'
            );
            $stmt->execute([
                ':uid' => $userId,
                ':aid' => $animeId,
                ':eid' => $episodeId,
            ]);
            $row = $stmt->fetch();
            Response::success([
                'anime_id'      => $animeId,
                'episode_id'    => $episodeId,
                'playback_time' => $row ? (int) $row['playback_time'] : 0,
                'updated_at'    => $row['updated_at'] ?? null,
            ]);
        }

        // Full history list.
        $stmt = db()->prepare(
            'SELECT anime_id, episode_id, playback_time, updated_at
               FROM watch_history
              WHERE user_id = :uid
           ORDER BY updated_at DESC'
        );
        $stmt->execute([':uid' => $userId]);
        Response::success($stmt->fetchAll());
        return;
    }

    if ($method === 'POST') {
        $body = Response::jsonBody();

        $animeId   = trim((string) ($body['anime_id'] ?? ''));
        $episodeId = trim((string) ($body['episode_id'] ?? ''));
        $playback  = (int) ($body['playback_time'] ?? 0);

        $errors = [];
        if ($animeId === '' || strlen($animeId) > 64) {
            $errors['anime_id'] = 'A valid anime_id is required.';
        }
        if ($episodeId === '' || strlen($episodeId) > 64) {
            $errors['episode_id'] = 'A valid episode_id is required.';
        }
        if ($playback < 0) {
            $errors['playback_time'] = 'playback_time must be a non-negative integer.';
        }
        if ($errors !== []) {
            Response::error('Validation failed.', 422, $errors);
        }

        $stmt = db()->prepare(
            'INSERT INTO watch_history (user_id, anime_id, episode_id, playback_time)
             VALUES (:uid, :aid, :eid, :pt)
             ON DUPLICATE KEY UPDATE playback_time = VALUES(playback_time)'
        );
        $stmt->execute([
            ':uid' => $userId,
            ':aid' => $animeId,
            ':eid' => $episodeId,
            ':pt'  => $playback,
        ]);

        Response::success([
            'anime_id'      => $animeId,
            'episode_id'    => $episodeId,
            'playback_time' => $playback,
        ], 201);
        return;
    }

    Response::error('Method not allowed.', 405);
} catch (Throwable $e) {
    error_log('history/index.php: ' . $e->getMessage());
    Response::error('Unexpected server error.', 500);
}
