<?php

declare(strict_types=1);

require_once dirname(__DIR__, 2) . '/middleware/auth_middleware.php';

/**
 * GET /api/auth/me.php   (protected)
 *
 * Returns the authenticated user's profile. Used by the client to restore a
 * session on startup and validate that the stored token is still good.
 */

Response::requireMethod('GET');

$userId = require_auth();

try {
    $stmt = db()->prepare(
        'SELECT id, name, email, created_at FROM users WHERE id = :id LIMIT 1'
    );
    $stmt->execute([':id' => $userId]);
    $user = $stmt->fetch();

    if ($user === false) {
        Response::error('User not found.', 404);
    }

    Response::success([
        'id'         => (int) $user['id'],
        'name'       => $user['name'],
        'email'      => $user['email'],
        'created_at' => $user['created_at'],
    ]);
} catch (Throwable $e) {
    error_log('me.php: ' . $e->getMessage());
    Response::error('Unexpected server error.', 500);
}
