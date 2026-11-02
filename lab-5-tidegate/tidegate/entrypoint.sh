#!/bin/sh
# Deploy-time provisioning. The partner token and the lab flags are
# generated when the container starts so they never sit in the image
# layers or in version control. Runs as root (the seal file is
# root-only by design); apache then serves requests as www-data.
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

# FLAG 1 sits in a database row reachable only through the public
# tracking query's boolean oracle (unauthenticated blind SQLi).
FLAG1="FLAG{tidegate_sqli_$(rand)}"
# FLAG 2 is a file on disk, readable by the service account — the
# payoff of an XXE file read (LFI).
FLAG2="FLAG{tidegate_xxe_$(rand)}"
# FLAG 3 is the root-only consignment seal — only the setuid helper can
# read it, so it falls only to genuine command execution.
FLAG3="FLAG{tidegate_rce_$(rand)}"

# The ingestion credential the blind SQLi is meant to lift.
PARTNER_TOKEN="$(rand)$(rand)"

sixs_emit l5-1 "$FLAG1"
sixs_emit l5-2 "$FLAG2"
sixs_emit l5-3 "$FLAG3"

mkdir -p /opt/tidegate

# LFI target: readable by the web account, which is what the XXE read
# runs as.
echo "$FLAG2" > /opt/tidegate/flag_manifest.txt
chown www-data:www-data /opt/tidegate/flag_manifest.txt
chmod 644 /opt/tidegate/flag_manifest.txt

# RCE target: root-only, read only through the setuid helper.
echo "$FLAG3" > /opt/tidegate/flag_seal.txt
chown root:root /opt/tidegate/flag_seal.txt
chmod 400 /opt/tidegate/flag_seal.txt

# Seed the gateway database with the flag and the partner token.
rm -f /opt/tidegate/tidegate.db
php /opt/tidegate/init_db.php "$FLAG1" "$PARTNER_TOKEN"
chown www-data:www-data /opt/tidegate/tidegate.db
chmod 644 /opt/tidegate/tidegate.db

chmod 755 /opt/tidegate

exec apache2-foreground
