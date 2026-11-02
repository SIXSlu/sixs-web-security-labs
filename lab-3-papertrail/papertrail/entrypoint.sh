#!/bin/sh
# Deploy-time provisioning. The lab flags are generated when the
# container starts so they never sit in the image layers or in git.
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

# FLAG 1 lives as the admin's status brief in the documents table; the
# only listed route to it is a signed-in admin session.
export PAPERTRAIL_FLAG1="FLAG{papertrail_prng_$(rand)}"
sixs_emit l3-1 "$PAPERTRAIL_FLAG1"

# One worker: the mail queue is process-local state and every thread
# shares it.
cd /opt/papertrail/app
exec gunicorn --workers 1 --threads 4 --bind 0.0.0.0:5000 \
    --access-logfile - app:app