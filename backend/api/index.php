<?php

declare(strict_types=1);

/**
 * Front controller (router) for the AnimeWatcher API.
 * ---------------------------------------------------
 * All API traffic is funnelled here by `.htaccess`, giving every endpoint a
 * clean, framework-style URL:
 *
 *     POST   /api/auth/login              →  api/auth/login.php
 *     POST   /api/auth/register           →  api/auth/register.php
 *     POST   /api/auth/logout             →  api/auth/logout.php
 *     GET    /api/auth/me                 →  api/auth/me.php
 *     GET    /api/favorites               →  api/favorites/index.php
 *     POST   /api/favorites               →  api/favorites/index.php
 *     DELETE /api/favorites               →  api/favorites/index.php
 *     GET    /api/history                 →  api/history/index.php
 *     POST   /api/history                 →  api/history/index.php
 *     GET    /api/anime/trending          →  api/anime/trending.php
 *     GET    /api/anime/details/{id}      →  api/anime/details.php  ($_GET['id'])
 *     GET    /api/episodes/sources        →  api/episodes/sources.php
 *
 * The router loads `bootstrap.php` first, which applies the CORS + JSON headers
 * and answers `OPTIONS` preflight requests immediately — so CORS and preflight
 * work uniformly for every routed endpoint. JWT middleware keeps working too:
 * the matched handler simply calls `require_auth()` as before, because the
 * router only *includes* the handler file rather than replacing it.
 *
 * Handlers remain individually addressable by their real `.php` path as well
 * (the `.htaccess` only rewrites requests that don't map to a real file), so
 * nothing that already worked is broken.
 */

require_once dirname(__DIR__) . '/src/bootstrap.php';

// -----------------------------------------------------------------------------
// 1. Work out the requested method and the route path relative to "/api".
// -----------------------------------------------------------------------------
$method = strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');

$rawPath = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
$rawPath = rawurldecode($rawPath);

// Strip everything up to and including the first "/api" segment so the router
// works whether the app is served from the domain root or a sub-directory.
$apiPos = strpos($rawPath, '/api');
$route  = $apiPos === false ? $rawPath : substr($rawPath, $apiPos + strlen('/api'));
$route  = '/' . trim($route, '/');

// A bare hit on the API root is a friendly liveness probe.
if ($route === '/' || $route === '/index.php') {
    Response::success(['service' => 'AnimeWatcher API', 'status' => 'ok']);
}

// -----------------------------------------------------------------------------
// 2. Route table.  Each entry: [METHODS, pattern, handler-file].
//    `{id}` in a pattern is a single path segment captured into $_GET['id'].
//    Endpoints that dispatch on the method internally (favorites, history) list
//    every method they accept so the router forwards instead of 405-ing.
// -----------------------------------------------------------------------------
$dir = __DIR__;

$routes = [
    // Auth
    [['POST'],                     '/auth/register',       $dir . '/auth/register.php'],
    [['POST'],                     '/auth/login',          $dir . '/auth/login.php'],
    [['POST'],                     '/auth/logout',         $dir . '/auth/logout.php'],
    [['GET'],                      '/auth/me',             $dir . '/auth/me.php'],

    // Favorites (protected — method handled inside the file)
    [['GET', 'POST', 'DELETE'],    '/favorites',           $dir . '/favorites/index.php'],

    // Watch history (protected — method handled inside the file)
    [['GET', 'POST'],              '/history',             $dir . '/history/index.php'],

    // Catalog (Jikan proxy + cache)
    [['GET'],                      '/anime/trending',      $dir . '/anime/trending.php'],
    [['GET'],                      '/anime/details/{id}',  $dir . '/anime/details.php'],

    // Video source scraping
    [['GET'],                      '/episodes/sources',    $dir . '/episodes/sources.php'],
];

// -----------------------------------------------------------------------------
// 3. Match and dispatch.
// -----------------------------------------------------------------------------
$pathMatched = false; // saw the path, but under a different method → 405 not 404

foreach ($routes as [$methods, $pattern, $handler]) {
    $params = [];
    if (!route_matches($pattern, $route, $params)) {
        continue;
    }

    $pathMatched = true;
    if (!in_array($method, $methods, true)) {
        continue;
    }

    // Expose captured path params (e.g. {id}) to the handler via $_GET, so a
    // handler can read `$_GET['id']` exactly like a normal query parameter.
    foreach ($params as $key => $value) {
        $_GET[$key] = $value;
    }

    if (!is_file($handler)) {
        error_log("router: missing handler file $handler for $route");
        Response::error('Endpoint is not available.', 500);
    }

    require $handler;
    exit; // handler is expected to terminate; guard against fall-through.
}

if ($pathMatched) {
    Response::error('Method not allowed.', 405);
}

Response::error('The requested endpoint was not found.', 404);

/**
 * Matches a route pattern against a concrete path.
 *
 * Supports `{name}` placeholders, each capturing exactly one path segment
 * (no slashes) into $params[name]. Matching is case-sensitive on static
 * segments and anchored end-to-end.
 *
 * @param array<string,string> $params Filled with captured segments on success.
 */
function route_matches(string $pattern, string $path, array &$params): bool
{
    $names = [];
    $regex = preg_replace_callback(
        '/\{([a-zA-Z_][a-zA-Z0-9_]*)\}/',
        static function (array $m) use (&$names): string {
            $names[] = $m[1];
            return '([^/]+)';
        },
        $pattern
    );

    if (preg_match('#^' . $regex . '$#', $path, $matches) !== 1) {
        return false;
    }

    array_shift($matches); // drop the full match
    foreach ($names as $i => $name) {
        $params[$name] = $matches[$i] ?? '';
    }
    return true;
}
