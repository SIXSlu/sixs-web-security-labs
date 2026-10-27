<?php
// PrintBay bootstrap: session, config, shared helpers.
declare(strict_types=1);

require_once __DIR__ . '/theme.php';
require_once __DIR__ . '/scriptlet.php';
require_once '/opt/printbay/config.php';

define('THEMES_DIR', __DIR__ . '/../themes');

session_start();

function db(): PDO
{
    static $pdo = null;
    if ($pdo === null) {
        $pdo = new PDO('sqlite:/opt/printbay/printbay.db', null, null, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]);
    }

    return $pdo;
}

// Tracking checksum printed on customer order links.
function tracking_hash(int $orderId): string
{
    return substr(sha1(APP_SECRET . '|' . $orderId), 0, 12);
}