<?php
// SQLite handle for the TideGate manifest gateway.
const TG_DB_PATH = '/opt/tidegate/tidegate.db';

function tg_db(): PDO
{
    static $pdo = null;
    if ($pdo === null) {
        $pdo = new PDO('sqlite:' . TG_DB_PATH);
        $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    }
    return $pdo;
}
