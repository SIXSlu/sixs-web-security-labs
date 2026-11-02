#!/bin/sh
# Deploy-time provisioning: the desk MOTD, the session secret and the
# lab flags are generated when the container starts so they never sit
# in the image layers or in version control.
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

FLAG1="FLAG{caseforge_prng_$(rand)}"
FLAG2="FLAG{caseforge_ssti_$(rand)}"
sixs_emit l2-cf-1 "$FLAG1"
sixs_emit l2-cf-2 "$FLAG2"

mkdir -p /opt/caseforge

# MOTD banner shown on the admin dashboard
python3 - "$FLAG1" <<'PY'
import sqlite3, sys

conn = sqlite3.connect("/opt/caseforge/caseforge.db")
conn.execute("CREATE TABLE IF NOT EXISTS settings ("
             "key TEXT PRIMARY KEY, value TEXT NOT NULL)")
conn.execute("INSERT OR REPLACE INTO settings (key, value) "
             "VALUES ('motd', ?)", (sys.argv[1],))
conn.commit()
PY

# the RCE flag is only readable by the service account
echo "${FLAG2}" > /opt/caseforge/flag_ssti.txt
chmod 600 /opt/caseforge/flag_ssti.txt

export CASEFORGE_SECRET_KEY="$(rand)$(rand)"

cd /opt/caseforge/app
exec gunicorn --workers 1 --threads 4 --bind 0.0.0.0:5000 --access-logfile - app:app