#!/bin/sh
# Runs as root (the seal file is root-only by design).
set -e

rand() { python3 -c "import secrets; print(secrets.token_hex(6))"; }
sixs_emit() {
  [ -w /flaghashes ] || return 0
  printf '%s' "$2" | sha256sum | cut -d' ' -f1 > "/flaghashes/$1.sha256" 2>/dev/null || true
  return 0
}

# The quarterly seal: root-owned, root-only, readable only through the
# compiled helper.
SEAL_FLAG="FLAG{intranet_rce_$(rand)}"
echo "$SEAL_FLAG" > /opt/intranet/flag_seal.txt
chown root:root /opt/intranet/flag_seal.txt
chmod 400 /opt/intranet/flag_seal.txt

export INTRANET_FLAG2="FLAG{intranet_ssrf_$(rand)}"
sixs_emit l3-3 "$SEAL_FLAG"
sixs_emit l3-2 "$INTRANET_FLAG2"

cd /opt/intranet/app
exec runuser -u intranet -- gunicorn --workers 1 --threads 4 \
    --bind 0.0.0.0:9000 --access-logfile - app:app