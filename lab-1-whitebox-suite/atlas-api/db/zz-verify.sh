#!/bin/sh
# Runs in Postgres initdb (after 01-init.sql). Best-effort: publish SHA-256
# of this start's SQL-minted flags to the shared verifier volume. Must never
# fail initdb, so everything is tolerant and it always exits 0.
D="atlas"
mkdir -p /flaghashes 2>/dev/null
emit() { printf '%s' "$2" | sha256sum | cut -d' ' -f1 > "/flaghashes/$1.sha256" 2>/dev/null; }
q() { psql -At -U "$POSTGRES_USER" -d "$D" -c "$1" 2>/dev/null; }
ADMIN="$(q "SELECT api_key FROM users WHERE username='admin'")"
BLIND="$(q "SELECT note FROM ops_notes WHERE note LIKE 'FLAG{%' LIMIT 1")"
BLIND="$(printf '%s' "$BLIND" | grep -oE 'FLAG\{[^}]*\}' | head -n1)"
[ -n "$ADMIN" ] && emit l1-atlas-1 "$ADMIN"
[ -n "$BLIND" ] && emit l1-atlas-2 "$BLIND"
exit 0
