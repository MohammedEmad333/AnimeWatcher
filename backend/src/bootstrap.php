<?php

declare(strict_types=1);

/**
 * Single include that every endpoint pulls in first. It loads configuration,
 * the database helper, JWT + Response utilities, and applies CORS/JSON headers
 * (answering preflight OPTIONS requests immediately).
 */

require_once dirname(__DIR__) . '/config/config.php';
require_once dirname(__DIR__) . '/config/database.php';
require_once dirname(__DIR__) . '/config/cors.php';
require_once __DIR__ . '/Jwt.php';
require_once __DIR__ . '/Response.php';

apply_cors_and_json_headers();
