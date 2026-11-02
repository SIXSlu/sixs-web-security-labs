#!/bin/sh
# Runs as root (the seal file is root-only by design).
set -e

rand() { python3 -c "import secrets; print(secrets.token_hex(6))"; }
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