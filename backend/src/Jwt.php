<?php

declare(strict_types=1);

require_once dirname(__DIR__) . '/config/config.php';

/**
 * Lightweight, dependency-free JWT handler (HS256).
 *
 * Implements just what this API needs: sign a payload and verify it. The
 * signature uses HMAC-SHA256 with the JWT_SECRET, and verification is
 * constant-time (hash_equals) to avoid timing attacks. Standard claims `iat`,
 * `exp` and `iss` are added automatically.
 *
 * For a larger project, firebase/php-jwt is a fine drop-in replacement — the
 * token format here is interoperable with it.
 */
final class Jwt
{
    /**
     * Signs $claims and returns a compact JWT string.
     *
     * @param array<string,mixed> $claims Application claims (e.g. user_id).
     */
    public static function encode(array $claims): string
    {
        $issuedAt = time();
        $ttl      = (int) (env('JWT_TTL', '604800')); // default 7 days

        $payload = array_merge($claims, [
            'iss' => env('JWT_ISSUER', 'animewatcher.api'),
            'iat' => $issuedAt,
            'exp' => $issuedAt + $ttl,
        ]);

        $header = ['alg' => 'HS256', 'typ' => 'JWT'];

        $segments = [
            self::base64UrlEncode(self::jsonEncode($header)),
            self::base64UrlEncode(self::jsonEncode($payload)),
        ];

        $signingInput = implode('.', $segments);
        $signature    = self::sign($signingInput);
        $segments[]   = self::base64UrlEncode($signature);

        return implode('.', $segments);
    }

    /**
     * Verifies a token and returns its claims.
     *
     * @return array<string,mixed> The decoded payload claims.
     * @throws RuntimeException When the token is malformed, has a bad
     *                          signature, or is expired.
     */
    public static function decode(string $token): array
    {
        $parts = explode('.', $token);
        if (count($parts) !== 3) {
            throw new RuntimeException('Malformed token.');
        }
        [$headerB64, $payloadB64, $signatureB64] = $parts;

        $header = json_decode(self::base64UrlDecode($headerB64), true);
        if (!is_array($header) || ($header['alg'] ?? '') !== 'HS256') {
            throw new RuntimeException('Unsupported token algorithm.');
        }

        // Recompute and compare the signature in constant time.
        $expected = self::sign($headerB64 . '.' . $payloadB64);
        $provided = self::base64UrlDecode($signatureB64);
        if (!hash_equals($expected, $provided)) {
            throw new RuntimeException('Invalid token signature.');
        }

        $payload = json_decode(self::base64UrlDecode($payloadB64), true);
        if (!is_array($payload)) {
            throw new RuntimeException('Invalid token payload.');
        }

        if (isset($payload['exp']) && time() >= (int) $payload['exp']) {
            throw new RuntimeException('Token has expired.');
        }

        return $payload;
    }

    private static function sign(string $input): string
    {
        $secret = env('JWT_SECRET');
        if ($secret === null || $secret === '' || $secret === 'change-me-to-a-64-char-random-hex-string') {
            // Fail closed rather than signing with a known/empty key.
            throw new RuntimeException('JWT secret is not configured.');
        }
        return hash_hmac('sha256', $input, $secret, true);
    }

    /** @param array<string,mixed> $data */
    private static function jsonEncode(array $data): string
    {
        return json_encode($data, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    }

    private static function base64UrlEncode(string $data): string
    {
        return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
    }

    private static function base64UrlDecode(string $data): string
    {
        $remainder = strlen($data) % 4;
        if ($remainder !== 0) {
            $data .= str_repeat('=', 4 - $remainder);
        }
        return base64_decode(strtr($data, '-_', '+/')) ?: '';
    }
}
