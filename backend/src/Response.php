<?php

declare(strict_types=1);

/**
 * Small helpers for consistent JSON I/O across every endpoint.
 *
 * Response envelope:
 *   success → { "success": true,  "data": ... }
 *   error   → { "success": false, "message": "...", "errors": {field: msg} }
 */
final class Response
{
    /**
     * Sends a success payload and terminates the request.
     *
     * @param mixed $data
     */
    public static function success($data = null, int $status = 200): never
    {
        http_response_code($status);
        echo json_encode(
            ['success' => true, 'data' => $data],
            JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE
        );
        exit;
    }

    /**
     * Sends an error payload and terminates the request.
     *
     * @param array<string,string> $errors Optional per-field validation errors.
     */
    public static function error(
        string $message,
        int $status = 400,
        array $errors = []
    ): never {
        http_response_code($status);
        $body = ['success' => false, 'message' => $message];
        if ($errors !== []) {
            $body['errors'] = $errors;
        }
        echo json_encode(
            $body,
            JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE
        );
        exit;
    }

    /**
     * Reads and decodes the JSON request body.
     *
     * @return array<string,mixed>
     */
    public static function jsonBody(): array
    {
        $raw = file_get_contents('php://input') ?: '';
        if (trim($raw) === '') {
            return [];
        }
        $decoded = json_decode($raw, true);
        if (!is_array($decoded)) {
            self::error('Request body must be valid JSON.', 400);
        }
        return $decoded;
    }

    /**
     * Ensures the request uses the expected HTTP method, else 405.
     */
    public static function requireMethod(string $method): void
    {
        if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== $method) {
            self::error('Method not allowed.', 405);
        }
    }
}
