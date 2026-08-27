<?php

declare(strict_types=1);

require_once dirname(__DIR__) . '/src/bootstrap.php';

/**
 * GET /api/health   (public, diagnostic)
 *
 * A zero-auth status report you can hit right after deploying to a new host to
 * see, at a glance, what works and what the environment blocks:
 *
 *   - php             → running version vs. the >=8.1 requirement
 *   - database        → can we open a PDO/MySQL connection and run a query
 *   - curl            → is the cURL extension available
 *   - outbound_jikan  → can the server actually reach the Jikan API (free hosts
 *                       like InfinityFree block outbound cURL — this is the
 *                       check that tells you whether the backend catalog proxy
 *                       and ScraperService can work on this host)
 *
 * Returns HTTP 200 when the critical checks (PHP + database) pass, or 503 when
 * they don't, so uptime monitors work too. `outbound_jikan` and `curl` are
 * reported but informational — the app calls Jikan directly, so the storage
 * features (auth/favorites/history) stay green even where outbound is blocked.
 */

Response::requireMethod('GET');

$checks = [];

// --- PHP ---------------------------------------------------------------------
$checks['php'] = [
    'ok'       => PHP_VERSION_ID >= 80100,
    'version'  => PHP_VERSION,
    'required' => '>=8.1',
];

// --- Database (PDO / MySQL) --------------------------------------------------
$db = ['ok' => false, 'driver' => 'mysql'];
try {
    $pdo = db();
    $pdo->query('SELECT 1');
    $db['ok']             = true;
    $db['message']        = 'connected';
    $db['server_version'] = (string) $pdo->getAttribute(PDO::ATTR_SERVER_VERSION);
} catch (Throwable $e) {
    // Log the real reason server-side; never leak DSN/credentials to clients.
    error_log('health.php db: ' . $e->getMessage());
    $db['message'] = 'connection failed';
}
$checks['database'] = $db;

// --- cURL extension ----------------------------------------------------------
$curlOk = function_exists('curl_init');
$checks['curl'] = [
    'ok'      => $curlOk,
    'version' => $curlOk ? (curl_version()['version'] ?? null) : null,
];

// --- Outbound reachability to Jikan -----------------------------------------
$jikanUrl = rtrim(env('JIKAN_BASE_URL', 'https://api.jikan.moe/v4') ?? '', '/') . '/anime/1';
$outbound = ['ok' => false, 'url' => $jikanUrl, 'reachable' => false];

if ($curlOk) {
    $ch = curl_init($jikanUrl);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_NOBODY         => true, // HEAD-style: we only need reachability
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_CONNECTTIMEOUT => 5,
        CURLOPT_TIMEOUT        => 8,
        CURLOPT_USERAGENT      => 'AnimeWatcher/health',
    ]);
    $start  = microtime(true);
    $res    = curl_exec($ch);
    $status = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $err    = curl_error($ch);
    curl_close($ch);

    $outbound['status']     = $status;
    $outbound['latency_ms'] = (int) round((microtime(true) - $start) * 1000);

    if ($res !== false && $status >= 200 && $status < 400) {
        $outbound['ok']        = true;
        $outbound['reachable'] = true;
        $outbound['message']   = 'outbound cURL works — backend Jikan proxy and ScraperService can function on this host';
    } else {
        $outbound['message'] = $err !== ''
            ? 'outbound blocked or failed: ' . $err
            : "outbound returned HTTP $status";
    }
} else {
    $outbound['message'] = 'cURL extension not available';
}
$checks['outbound_jikan'] = $outbound;

// --- Verdict -----------------------------------------------------------------
// PHP + database are critical for auth/favorites/history. curl + outbound are
// informational (the app talks to Jikan directly).
$critical = $checks['php']['ok'] && $checks['database']['ok'];

$report = [
    'status'    => $critical ? 'ok' : 'degraded',
    'timestamp' => gmdate('c'),
    'checks'    => $checks,
    'notes'     => [
        'Auth, Favorites and History require only PHP + database.',
        'Trending/Details are fetched from Jikan directly by the app.',
        'The backend catalog proxy and ScraperService additionally need outbound cURL (see outbound_jikan).',
    ],
];

http_response_code($critical ? 200 : 503);
echo json_encode(
    ['success' => $critical, 'data' => $report],
    JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE
);
exit;
