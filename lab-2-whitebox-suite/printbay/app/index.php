<?php
// PrintBay front controller. Every page is routed through here.
declare(strict_types=1);

require_once __DIR__ . '/lib/bootstrap.php';

$page = $_GET['page'] ?? 'home';

switch ($page) {
    case 'home':
        include THEMES_DIR . '/home.php';
        break;

    case 'gallery':
        include THEMES_DIR . '/gallery.php';
        break;

    case 'preview':
        printbay_preview();
        break;

    case 'admin':
        printbay_admin();
        break;

    case 'scriptlets':
        printbay_scriptlets();
        break;

    default:
        http_response_code(404);
        include THEMES_DIR . '/404.php';
}