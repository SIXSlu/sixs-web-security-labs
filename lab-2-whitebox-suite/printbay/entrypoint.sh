#!/bin/sh
# Deploy-time provisioning: the support token and the lab flags are
# generated when the container starts so they never sit in the image
# layers or in version control.
set -e

rand() { php -r "echo bin2hex(random_bytes(6));"; }
sixs_emit() {
  [ -w /flaghashes ] || return 0
  f="/flaghashes/$1.sha256"
  # Drop any previous hash first: a bare `>` only truncates, which a
  # leftover file owned by another uid refuses even in the 1777 dir.
  rm -f "$f" 2>/dev/null || true
  printf '%s' "$2" | sha256sum | cut -d' ' -f1 > "$f" 2>/dev/null \
    || echo "sixs_emit: could not publish $f; the verifier will miss this flag" >&2
  return 0
}

FLAG1="FLAG{printbay_leak_$(rand)}"
FLAG2="FLAG{printbay_chain_$(rand)}"
FLAG3="FLAG{printbay_eval_$(rand)}"
SUPPORT_TOKEN="$(rand)$(rand)"
sixs_emit l2-pb-1 "$FLAG1"
sixs_emit l2-pb-2 "$FLAG2"
sixs_emit l2-pb-3 "$FLAG3"

mkdir -p /opt/printbay

cat > /opt/printbay/config.php <<EOF
<?php
// Generated at deployment. The support token is the hotline fallback
// printed on the card in the shop safe - keep it sealed.
define('APP_SECRET', '$(rand)$(rand)');
define('SUPPORT_TOKEN', '$SUPPORT_TOKEN');
EOF

cat > /opt/printbay/flag3_config.php <<EOF
<?php
// Generated at deployment - ops snippet helper.
if (!function_exists('printbay_flag3')) {
    function printbay_flag3(): string
    {
        // Quarterly scriptlet benchmark token (rotates on redeploy).
        return '$FLAG3';
    }
}
EOF

# the RCE flag is only readable by the web account
echo "${FLAG2}" > /opt/printbay/flag_chain.txt

chown www-data:www-data /opt/printbay/config.php /opt/printbay/flag3_config.php /opt/printbay/flag_chain.txt
chmod 600 /opt/printbay/config.php /opt/printbay/flag3_config.php /opt/printbay/flag_chain.txt

rm -f /opt/printbay/printbay.db
php /opt/printbay/init_db.php "$FLAG1"
chown www-data:www-data /opt/printbay/printbay.db
chmod 600 /opt/printbay/printbay.db
chown www-data:www-data /opt/printbay
chmod 750 /opt/printbay

exec apache2-foreground