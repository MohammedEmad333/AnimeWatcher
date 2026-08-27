<?php

declare(strict_types=1);

require_once __DIR__ . '/config.php';

/**
 * Emits CORS + JSON headers and short-circuits CORS preflight requests.
 *
 * The allowed origins come from CORS_ALLOWED_ORIGINS (comma-separated). When
 * it is `*`, any origin is echoed back — convenient for local development but
 * you should pin explicit origins in production. Because the API is
 * token-based (Authorization header, not cookies), credentials are not
 * enabled, so reflecting the origin is safe.
 */
function apply_cors_and_json_headers(): void
{
    header('Content-Type: application/json; charset=utf-8');
    header('Vary: Origin');

    $allowed = array_map('trim', explode(',', env('CORS_ALLOWED_ORIGINS', '*') ?? '*'));
    $origin  = $_SERVER['HTTP_ORIGIN'] ?? '';

    if (in_array('*', $allowed, true)) {
        header('Access-Control-Allow-Origin: *');
    } elseif ($origin !== '' && in_array($origin, $allowed, true)) {
        header('Access-Control-Allow-Origin: ' . $origin);
    }

    header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, Authorization');
    header('Access-Control-Max-Age: 86400');

    // Answer preflight immediately with no body.
    if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'OPTIONS') {
        http_response_code(204);
        exit;
    }
}
