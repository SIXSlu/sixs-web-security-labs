#!/bin/sh
# Deploy-time provisioning: the diagnostics key and the RCE flag are
# generated when the container starts so they never sit in the image
# layers or in version control.
set -e

rand() { node -e "process.stdout.write(require('crypto').randomBytes(8).toString('hex'))"; }
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

FLAG1="FLAG{reportsmith_pollution_$(rand)}"
FLAG2="FLAG{reportsmith_ejs_rce_$(rand)}"
sixs_emit l1-rs-1 "$FLAG1"
sixs_emit l1-rs-2 "$FLAG2"

echo "${FLAG1}" > /opt/reportsmith/diag.key
chmod 644 /opt/reportsmith/diag.key

# the RCE flag is only readable by the service account
echo "${FLAG2}" > /home/node/flag_reportsmith.txt
chmod 600 /home/node/flag_reportsmith.txt

cd /opt/reportsmith/app
exec node server.js