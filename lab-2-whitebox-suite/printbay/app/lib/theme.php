<?php
// Template preview helpers.
//
// The preview screen lets a customer try any shipped theme before
// ordering. The design team additionally keeps work-in-progress comps
// on scratch streams (php://temp), which is why stream wrappers stay
// enabled for the previewer.
declare(strict_types=1);

function theme_path(string $theme): string
{
    if ($theme === '') {
        return 'default.php';
    }
    if ($theme[0] === '/') {
        throw new RuntimeException('absolute paths are not allowed');
    }
    if (str_contains($theme, '../')) {
        throw new RuntimeException('path traversal is not allowed');
    }
    // Remote wrappers were disabled after a comp pulled from the old
    // staging ftp box broke the previewer for everyone.
    foreach (['http://', 'https://', 'ftp://', 'data://', 'phar://', 'zip://', 'file://'] as $scheme) {
        if (stripos($theme, $scheme) === 0) {
            throw new RuntimeException('remote wrappers are not allowed');
        }
    }

    return $theme;
}

function printbay_preview(): void
{
    // The preview form posts, but customers also paste previewed links
    // around, so accept the theme from either place.
    $theme = (string)($_REQUEST['theme'] ?? 'default');

    try {
        $path = theme_path($theme);
    } catch (RuntimeException $e) {
        http_response_code(400);
        include THEMES_DIR . '/404.php';
        return;
    }

    include THEMES_DIR . '/preview.php';

    if (str_contains($path, '://')) {
        // Designers' scratch space: hand the stream wrapper straight to
        // include() so the comp is rendered inline.
        include $path;
    } else {
        $file = THEMES_DIR . '/' . $path;
        if (!is_file($file)) {
            echo '<p class="error">theme not found: ' . htmlspecialchars($path) . '</p>';
            include THEMES_DIR . '/404.php';
            return;
        }
        include $file;
    }

    include THEMES_DIR . '/preview_footer.php';
}

function printbay_admin(): void
{
    $token = (string)($_GET['token'] ?? '');
    if ($token !== '' && hash_equals(SUPPORT_TOKEN, $token)) {
        // Support hotline card (printed once, kept in the shop safe):
        // boots a fresh admin session for the on-call technician.
        $_SESSION['is_admin'] = true;
    }

    if (empty($_SESSION['is_admin'])) {
        http_response_code(403);
        include THEMES_DIR . '/403.php';
        return;
    }

    $db = db();
    $banner = $db->query("SELECT value FROM settings WHERE key = 'ops_banner'")->fetchColumn();
    $orders = $db->query('SELECT id, customer, product, status FROM orders ORDER BY id')->fetchAll();
    include THEMES_DIR . '/admin.php';
}

function printbay_scriptlets(): void
{
    if (empty($_SESSION['is_admin'])) {
        http_response_code(403);
        header('Content-Type: application/json');
        echo json_encode(['ok' => false, 'error' => 'admin session required']);
        return;
    }

    header('Content-Type: application/json');
    $body = json_decode((string)file_get_contents('php://input'), true);
    $code = (string)($body['code'] ?? '');
    if (trim($code) === '') {
        echo json_encode(['ok' => false, 'error' => 'empty scriptlet']);
        return;
    }

    // Deployment snippet helper (quarterly benchmark token etc.).
    require_once '/opt/printbay/flag3_config.php';

    try {
        $output = ScriptletEngine::run($code);
        echo json_encode(['ok' => true, 'output' => $output]);
    } catch (ScriptletException $e) {
        echo json_encode(['ok' => false, 'error' => $e->getMessage()]);
    }
}