<?php

declare(strict_types=1);

/**
 * Standalone sanity checks for the JWT handler. No DB or web server needed:
 *
 *   JWT_SECRET=test-secret php backend/tests/jwt_test.php
 */

putenv('JWT_SECRET=' . (getenv('JWT_SECRET') ?: 'unit-test-secret-please-change'));
$_ENV['JWT_SECRET'] = getenv('JWT_SECRET');

require_once dirname(__DIR__) . '/src/Jwt.php';

$failures = 0;
function check(string $label, bool $ok): void
{
    global $failures;
    echo ($ok ? "  ok   " : "  FAIL ") . $label . PHP_EOL;
    if (!$ok) {
        $failures++;
    }
}

// 1. Round-trip: the decoded payload carries our claim.
$token   = Jwt::encode(['user_id' => 42]);
$claims  = Jwt::decode($token);
check('round-trip preserves user_id', ($claims['user_id'] ?? null) === 42);
check('adds iat/exp/iss claims', isset($claims['iat'], $claims['exp'], $claims['iss']));

// 2. Tampering with the payload invalidates the signature.
$parts       = explode('.', $token);
$parts[1]    = rtrim(strtr(base64_encode('{"user_id":999}'), '+/', '-_'), '=');
$tampered    = implode('.', $parts);
$rejected    = false;
try {
    Jwt::decode($tampered);
} catch (Throwable $e) {
    $rejected = true;
}
check('rejects a tampered payload', $rejected);

// 3. Malformed tokens are rejected.
$malformedRejected = false;
try {
    Jwt::decode('not-a-jwt');
} catch (Throwable $e) {
    $malformedRejected = true;
}
check('rejects a malformed token', $malformedRejected);

// 4. Expired tokens are rejected (TTL of 0 → exp == iat <= now).
putenv('JWT_TTL=0');
$_ENV['JWT_TTL'] = '0';
$expired = Jwt::encode(['user_id' => 1]);
sleep(1);
$expiredRejected = false;
try {
    Jwt::decode($expired);
} catch (Throwable $e) {
    $expiredRejected = true;
}
check('rejects an expired token', $expiredRejected);

echo PHP_EOL . ($failures === 0 ? "All JWT tests passed." : "$failures test(s) FAILED.") . PHP_EOL;
exit($failures === 0 ? 0 : 1);
