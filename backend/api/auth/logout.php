<?php

declare(strict_types=1);

require_once dirname(__DIR__, 2) . '/middleware/auth_middleware.php';

/**
 * POST /api/auth/logout.php   (protected)
 *
 * JWTs are stateless, so "logout" is primarily a client-side action (the app
 * discards the token). This endpoint exists so the client has a single call to
 * make; a production system could additionally record the token's `jti` in a
 * denylist until it expires. We simply verify the token and acknowledge.
 */

Response::requireMethod('POST');

require_auth();

Response::success(['message' => 'Logged out.']);
