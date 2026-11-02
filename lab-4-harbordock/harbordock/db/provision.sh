#!/bin/sh
# Runtime provisioning: mint the ops token and the flag values, then
# upsert them into the database. Runs on every compose start, so the
# values are fresh while the schema survives any restart.
set -e

rand() { tr -dc 'a-f0-9' < /dev/urandom | head -c 12; }

until psql -h harbordock-db -U postgres -d harbordock -c '\q'; do
  sleep 2
done

export PGPASSWORD=postgres
DB="harbordock-db"
USER="postgres"

FLAG_SQLI="FLAG{harbordock_sqli_$(rand)}"
FLAG_VAULT="FLAG{harbordock_vault_$(rand)}"
OPS_TOKEN="$(rand)$(rand)"

psql -h $DB -U $USER -d harbordock <<SQL
DELETE FROM system_notes WHERE note LIKE 'FLAG{%';
INSERT INTO system_notes (note) VALUES ('${FLAG_SQLI}');
INSERT INTO token_vault (label, value) VALUES ('seal', '${FLAG_VAULT}')
    ON CONFLICT (label) DO UPDATE SET value = EXCLUDED.value;
INSERT INTO token_vault (label, value) VALUES ('api_ops', '${OPS_TOKEN}')
    ON CONFLICT (label) DO UPDATE SET value = EXCLUDED.value;
SQL

mkdir -p /flaghashes 2>/dev/null || true
# Remove before writing: a bare `>` only truncates, which a leftover hash
# file owned by another uid refuses even in the 1777 dir — the panel would
# then keep verifying against a stale flag from an earlier stack run.
rm -f /flaghashes/l4-1.sha256 /flaghashes/l4-2.sha256 2>/dev/null || true
printf '%s' "$FLAG_SQLI"  | sha256sum | cut -d' ' -f1 > /flaghashes/l4-1.sha256 2>/dev/null \
  || echo "provision: could not publish l4-1 hash; the verifier will reject this flag" >&2
printf '%s' "$FLAG_VAULT" | sha256sum | cut -d' ' -f1 > /flaghashes/l4-2.sha256 2>/dev/null \
  || echo "provision: could not publish l4-2 hash; the verifier will reject this flag" >&2
echo "provision: token_vault and notes minted for this start"