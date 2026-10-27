<?php
// Public consignment tracking. No authentication: anyone with a
// reference can check clearance status.
//
// The reference is concatenated straight into the lookup. The page
// only ever reveals ONE bit per request — whether a manifest matched —
// so this is a boolean oracle, not a data dump. Everything of value
// (the partner API token in `partners`, the seal in `ops_secrets`) has
// to be reconstructed one truth-value at a time.
require __DIR__ . '/view.php';
require __DIR__ . '/db.php';

$ref = $_GET['ref'] ?? '';

$result = null;
if ($ref !== '') {
    $sql = "SELECT ref, status FROM manifests WHERE ref = '" . $ref . "'";
    try {
        $row = tg_db()->query($sql)->fetch(PDO::FETCH_ASSOC);
        $result = $row ?: false;
    } catch (Throwable $e) {
        // A malformed reference is just "not found" to the customs desk.
        $result = false;
    }
}

$panel = '';
if ($ref !== '') {
    if ($result) {
        $status = htmlspecialchars($result['status'], ENT_QUOTES);
        $panel = "<div class=\"card\"><p class=\"ok\">Manifest on file.</p>"
               . "<p>Clearance status: <code>$status</code></p></div>";
    } else {
        $panel = "<div class=\"card\"><p class=\"bad\">No manifest on file for"
               . " that reference.</p></div>";
    }
}

$safeRef = htmlspecialchars($ref, ENT_QUOTES);
$body = <<<HTML
<h1>Consignment tracking</h1>
<div class="card" style="max-width:30rem">
<form method="get" action="/track.php">
  <label>Manifest reference <input name="ref" value="$safeRef" placeholder="TG-1001"></label>
  <button>Track</button>
</form>
</div>
$panel
HTML;

echo tg_page('TideGate — tracking', 'tracking', $body);
