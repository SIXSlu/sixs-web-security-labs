<?php
// TideGate manifest ingestion. Partner-authenticated XML intake.
//
//   POST /gateway/ingest.php
//   X-Partner-Token: <the partner's api_token>
//   body: a <Manifest> XML document
//
// The gateway parses the manifest, returns a clearance receipt that
// echoes the declared consignee and reference, and — if the manifest
// carries a <MappingSheet> — applies that sheet to normalise partner
// field names before filing.
//
// Two decisions here are load-bearing:
//   1. The manifest is parsed with entity substitution and DTD loading
//      turned on, so a partner can define reusable entities for repeated
//      consignee blocks. External entities are not filtered.
//   2. The optional field-mapping sheet is a partner-supplied XSLT
//      stylesheet, applied with PHP functions registered so legacy
//      partners can call helper routines during mapping.

require __DIR__ . '/../db.php';

header('Content-Type: text/plain; charset=utf-8');

function fail(int $code, string $msg): never
{
    http_response_code($code);
    echo $msg . "\n";
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    fail(405, 'POST a manifest document to this endpoint.');
}

// --- partner authentication -------------------------------------------
// Prepared lookup: the token must be the real one. (The way to learn a
// valid token is the public tracking oracle, not this endpoint.)
$headers = function_exists('getallheaders') ? getallheaders() : [];
$token = $headers['X-Partner-Token']
      ?? $headers['X-Partner-token']
      ?? ($_SERVER['HTTP_X_PARTNER_TOKEN'] ?? '');
$token = trim((string) $token);

if ($token === '') {
    fail(401, 'Missing X-Partner-Token.');
}
$stmt = tg_db()->prepare('SELECT name FROM partners WHERE api_token = ?');
$stmt->execute([$token]);
$partner = $stmt->fetchColumn();
if ($partner === false) {
    fail(403, 'Partner token not recognised.');
}

// --- read + parse the manifest ----------------------------------------
$raw = file_get_contents('php://input');
if ($raw === '' || $raw === false) {
    fail(400, 'Empty manifest body.');
}

$dom = new DOMDocument();
$prev = libxml_use_internal_errors(true);
$ok = $dom->loadXML($raw, LIBXML_NOENT | LIBXML_DTDLOAD);
libxml_use_internal_errors($prev);
if (!$ok) {
    fail(400, 'Manifest did not parse as XML.');
}

// Pull the declared header fields for the receipt.
$ref = tg_text($dom, 'Reference');
$consignee = tg_text($dom, 'Consignee');

echo "TideGate clearance receipt\n";
echo "partner:   $partner\n";
echo "reference: $ref\n";
echo "consignee: $consignee\n";

// --- optional field-mapping transform ---------------------------------
// If the manifest embeds a <MappingSheet>, apply the partner's XSLT so
// their field names map onto ours. PHP functions are registered for
// legacy partners whose sheets call helper routines.
$sheetNode = $dom->getElementsByTagName('MappingSheet')->item(0);
if ($sheetNode instanceof DOMElement) {
    $sheetXml = '';
    foreach ($sheetNode->childNodes as $child) {
        if ($child instanceof DOMElement) {
            $sheetXml = $dom->saveXML($child);
            break;
        }
    }
    if ($sheetXml !== '') {
        $xsl = new DOMDocument();
        if ($xsl->loadXML($sheetXml)) {
            $proc = new XSLTProcessor();
            $proc->registerPHPFunctions();
            $proc->importStylesheet($xsl);
            $mapped = $proc->transformToXML($dom);
            echo "\n-- mapped --\n";
            echo $mapped;
        }
    }
}

function tg_text(DOMDocument $dom, string $tag): string
{
    $node = $dom->getElementsByTagName($tag)->item(0);
    return $node ? trim($node->textContent) : '(none)';
}
