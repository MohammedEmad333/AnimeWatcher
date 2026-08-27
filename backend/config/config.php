<?php

declare(strict_types=1);

/**
 * Loads configuration from a `.env` file (if present) and the process
 * environment, exposing everything through the env() helper.
 *
 * A tiny hand-rolled loader is used to avoid a Composer dependency; in
 * production you may prefer vlucas/phpdotenv or real server env vars.
 */

if (!function_exists('env')) {
    /**
     * Reads a configuration value, falling back to $default when unset.
     */
    function env(string $key, ?string $default = null): ?string
    {
        $value = $_ENV[$key] ?? getenv($key);
        if ($value === false || $value === null || $value === '') {
            return $default;
        }
        return (string) $value;
    }
}

/**
 * Parses a `.env` file into $_ENV without overwriting existing values.
 */
(function (): void {
    $path = dirname(__DIR__) . '/.env';
    if (!is_readable($path)) {
        return;
    }
    $lines = file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($lines as $line) {
        $line = trim($line);
        if ($line === '' || str_starts_with($line, '#')) {
            continue;
        }
        [$name, $value] = array_pad(explode('=', $line, 2), 2, '');
        $name = trim($name);
        $value = trim($value, " \t\"'");
        if ($name !== '' && !array_key_exists($name, $_ENV)) {
            $_ENV[$name] = $value;
        }
    }
})();
