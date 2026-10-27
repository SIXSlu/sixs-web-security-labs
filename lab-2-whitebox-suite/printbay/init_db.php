<?php
// One-time DB provisioning, invoked by the container entrypoint so the
// ops banner rotates with every deployment.
if (!isset($argv[1])) {
    fwrite(STDERR, "usage: php init_db.php <ops_banner>\n");
    exit(1);
}
$banner = $argv[1];

$db = new PDO('sqlite:/opt/printbay/printbay.db', null, null, [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
]);
$db->exec('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
$db->exec('CREATE TABLE orders (id INTEGER PRIMARY KEY, customer TEXT NOT NULL, product TEXT NOT NULL, status TEXT NOT NULL)');

$stmt = $db->prepare('INSERT INTO orders (customer, product, status) VALUES (?, ?, ?)');
foreach ([
    ['Alvarez & Sons Plumbing', '250 business cards', 'done'],
    ['Pinegrove Farmers Market', '400 A5 flyers', 'printed'],
    ['Cafe Meridian', '60 menu cards', 'queued'],
    ['K. Whitfield', '2 vinyl banners', 'printed'],
    ['Pinegrove Animal Shelter', '300 adoption flyers', 'queued'],
    ['Harbour Dental', '150 appointment cards', 'done'],
] as $row) {
    $stmt->execute($row);
}

$stmt = $db->prepare('INSERT INTO settings (key, value) VALUES (?, ?)');
$stmt->execute(['ops_banner', $banner]);
$stmt->execute(['shop_name', 'PrintBay Pinegrove']);

echo "provisioned /opt/printbay/printbay.db\n";