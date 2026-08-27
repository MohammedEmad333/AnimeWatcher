<?php

declare(strict_types=1);

require_once __DIR__ . '/config.php';

/**
 * Creates and returns a shared PDO connection configured for safety:
 *
 *  - ERRMODE_EXCEPTION   → errors throw, so try/catch works everywhere.
 *  - EMULATE_PREPARES=false → real server-side prepared statements (defeats
 *    SQL injection and keeps types intact).
 *  - DEFAULT_FETCH_MODE=ASSOC → predictable associative rows.
 *  - utf8mb4 charset for full Unicode (emoji, Arabic, Japanese titles).
 *
 * The connection is memoized so repeated calls within one request reuse it.
 */
function db(): PDO
{
    static $pdo = null;
    if ($pdo instanceof PDO) {
        return $pdo;
    }

    $host = env('DB_HOST', '127.0.0.1');
    $port = env('DB_PORT', '3306');
    $name = env('DB_NAME', 'anime_watcher');

    $dsn = sprintf(
        'mysql:host=%s;port=%s;dbname=%s;charset=utf8mb4',
        $host,
        $port,
        $name
    );

    $pdo = new PDO(
        $dsn,
        env('DB_USER', 'root'),
        env('DB_PASS', ''),
        [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
        ]
    );

    return $pdo;
}
