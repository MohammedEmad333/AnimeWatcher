<?php

declare(strict_types=1);

require_once dirname(__DIR__) . '/src/bootstrap.php';

/**
 * Auth guard for protected routes.
 *
 * Reads the `Authorization: Bearer <token>` header, verifies the JWT, and
 * returns the authenticated user's id. On any failure it emits a `401` JSON
 * response and terminates — so a protected endpoint can simply do:
 *
 *     $userId = require_auth();
 *
 * and trust that everything past that line runs for an authenticated user.
 */
function require_auth(): int
{
    $token = bearer_token();
    if ($token === null) {
        Response::error('Missing or malformed Authorization header.', 401);
    }

    try {
        $claims = Jwt::decode($token);
    } catch (Throwable $e) {
        // Do not leak the specific reason (expired vs. bad signature).
        Response::error('Invalid or expired token.', 401);
    }

    $userId = isset($claims['user_id']) ? (int) $claims['user_id'] : 0;
    if ($userId <= 0) {
        Response::error('Invalid token subject.', 401);
    }

    return $userId;
}

/**
 * Extracts the bearer token from the request, coping with the various ways
 * servers expose the Authorization header (Apache often strips it unless the
 * bundled .htaccess forwards it).
 */
function bearer_token(): ?string
{
    $header = $_SERVER['HTTP_AUTHORIZATION']
        ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION']
        ?? '';

    if ($header === '' && function_exists('apache_request_headers')) {
        $headers = apache_request_headers();
        $header  = $headers['Authorization'] ?? $headers['authorization'] ?? '';
    }

    if (preg_match('/^Bearer\s+(.+)$/i', trim($header), $matches) === 1) {
        return trim($matches[1]);
    }

    return null;
}
