<?php

declare(strict_types=1);

require_once dirname(__DIR__, 2) . '/src/bootstrap.php';

/**
 * POST /api/auth/login.php
 *
 * Body: { "email": "...", "password": "..." }
 * Verifies credentials and returns a JWT containing the user_id plus the
 * user profile: { token, user }.
 */

Response::requireMethod('POST');

$body = Response::jsonBody();

$email    = strtolower(trim((string) ($body['email'] ?? '')));
$password = (string) ($body['password'] ?? '');

if ($email === '' || $password === '') {
    Response::error('Email and password are required.', 422);
}

try {
    $stmt = db()->prepare(
        'SELECT id, name, email, password FROM users WHERE email = :email LIMIT 1'
    );
    $stmt->execute([':email' => $email]);
    $user = $stmt->fetch();

    // Use the same generic message whether the email is unknown or the
    // password is wrong, so we don't reveal which emails are registered.
    if ($user === false || !password_verify($password, $user['password'])) {
        Response::error('Invalid email or password.', 401);
    }

    // Transparently upgrade legacy hashes if the algorithm/cost changed.
    if (password_needs_rehash($user['password'], PASSWORD_DEFAULT)) {
        $rehash = password_hash($password, PASSWORD_DEFAULT);
        $upd = db()->prepare('UPDATE users SET password = :p WHERE id = :id');
        $upd->execute([':p' => $rehash, ':id' => $user['id']]);
    }

    $userId = (int) $user['id'];
    $token  = Jwt::encode(['user_id' => $userId]);

    Response::success([
        'token' => $token,
        'user'  => [
            'id'    => $userId,
            'name'  => $user['name'],
            'email' => $user['email'],
        ],
    ]);
} catch (Throwable $e) {
    error_log('login.php: ' . $e->getMessage());
    Response::error('Unexpected server error.', 500);
}
