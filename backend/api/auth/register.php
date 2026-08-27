<?php

declare(strict_types=1);

require_once dirname(__DIR__, 2) . '/src/bootstrap.php';

/**
 * POST /api/auth/register.php
 *
 * Body: { "name": "...", "email": "...", "password": "..." }
 * On success creates the user, issues a JWT, and returns { token, user }
 * (auto-login) so the client can proceed immediately.
 */

Response::requireMethod('POST');

$body = Response::jsonBody();

$name     = trim((string) ($body['name'] ?? ''));
$email    = strtolower(trim((string) ($body['email'] ?? '')));
$password = (string) ($body['password'] ?? '');

// --- Validation -------------------------------------------------------------
$errors = [];
if ($name === '' || mb_strlen($name) > 100) {
    $errors['name'] = 'Name is required (max 100 characters).';
}
if ($email === '' || !filter_var($email, FILTER_VALIDATE_EMAIL) || strlen($email) > 191) {
    $errors['email'] = 'A valid email is required.';
}
// 6+ to match the client; 8+ is recommended. bcrypt caps at 72 bytes.
if (strlen($password) < 6) {
    $errors['password'] = 'Password must be at least 6 characters.';
} elseif (strlen($password) > 72) {
    $errors['password'] = 'Password must be at most 72 characters.';
}
if ($errors !== []) {
    Response::error('Validation failed.', 422, $errors);
}

// --- Persist ----------------------------------------------------------------
try {
    $hash = password_hash($password, PASSWORD_DEFAULT);

    $stmt = db()->prepare(
        'INSERT INTO users (name, email, password) VALUES (:name, :email, :password)'
    );
    $stmt->execute([
        ':name'     => $name,
        ':email'    => $email,
        ':password' => $hash,
    ]);

    $userId = (int) db()->lastInsertId();

    $token = Jwt::encode(['user_id' => $userId]);

    Response::success([
        'token' => $token,
        'user'  => [
            'id'    => $userId,
            'name'  => $name,
            'email' => $email,
        ],
    ], 201);
} catch (PDOException $e) {
    // 23000 = integrity constraint violation (duplicate unique email).
    if ($e->getCode() === '23000') {
        Response::error('An account with this email already exists.', 409);
    }
    // Log the real error server-side; return a generic message to the client.
    error_log('register.php: ' . $e->getMessage());
    Response::error('Could not create the account. Please try again.', 500);
} catch (Throwable $e) {
    error_log('register.php: ' . $e->getMessage());
    Response::error('Unexpected server error.', 500);
}
