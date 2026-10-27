<?php
// Deploy-time seed for the TideGate gateway database.
//   argv[1] = FLAG 1  (lands in ops_secrets, reachable only via the
//                       public tracking query)
//   argv[2] = partner API token (the ingestion credential the blind
//                       SQLi is meant to lift and carry to stage 2)
//
// The flag and the token sit in rows that no page ever prints: the
// tracking endpoint only tells you whether a manifest reference exists.
// Everything here is reachable only by abusing that yes/no oracle.

$flag1 = $argv[1] ?? 'FLAG{tidegate_unset_1}';
$token = $argv[2] ?? 'deadbeef';

$db = new PDO('sqlite:/opt/tidegate/tidegate.db');
$db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
$db->exec('DROP TABLE IF EXISTS manifests');
$db->exec('DROP TABLE IF EXISTS partners');
$db->exec('DROP TABLE IF EXISTS ops_secrets');

$db->exec('CREATE TABLE manifests (
    ref       TEXT PRIMARY KEY,
    consignee TEXT NOT NULL,
    status    TEXT NOT NULL
)');
$db->exec('CREATE TABLE partners (
    id        INTEGER PRIMARY KEY,
    name      TEXT NOT NULL,
    api_token TEXT NOT NULL
)');
$db->exec('CREATE TABLE ops_secrets (
    k TEXT PRIMARY KEY,
    v TEXT NOT NULL
)');

// Public-looking tracking data, so the lookup endpoint has real rows.
$manifests = [
    ['TG-1001', 'Northgate Freight',   'cleared'],
    ['TG-1002', 'Harbour Works Ltd',   'held at customs'],
    ['TG-1003', 'Meridian Shipping',   'in transit'],
    ['TG-1004', 'Northgate Freight',   'awaiting duty'],
    ['TG-1005', 'Coastal Bulk Co',     'cleared'],
];
$ins = $db->prepare('INSERT INTO manifests (ref, consignee, status) VALUES (?, ?, ?)');
foreach ($manifests as $m) {
    $ins->execute($m);
}

// The ingestion credential. Partner id 1 is the account the gateway
// trusts for XML submission; its token gates POST /gateway/ingest.
$db->prepare('INSERT INTO partners (id, name, api_token) VALUES (1, ?, ?)')
   ->execute(['Northgate Freight', $token]);

// FLAG 1 lives here and nowhere on any rendered page.
$db->prepare('INSERT INTO ops_secrets (k, v) VALUES (?, ?)')
   ->execute(['gateway_seal', $flag1]);

echo "seeded\n";
