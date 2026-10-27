#!/bin/sh
# Runs in Postgres initdb (after 01-init.sql). Best-effort: publish SHA-256
# of this start's SQL-minted flags to the shared verifier volume. Must never
# fail initdb, so everything is tolerant and it always exits 0.
D="fleet"
mkdir -p /flaghashes 2>/dev/null
emit() { printf '%s' "$2" | sha256sum | cut -d' ' -f1 > "/flaghashes/$1.sha256" 2>/dev/null; }
q() { psql -At -U "$POSTGRES_USER" -d "$D" -c "$1" 2>/dev/null; }
UNION="$(q "SELECT value FROM settings WHERE key='console_banner'")"
BLIND="$(q "SELECT note FROM maintenance_notes WHERE note LIKE 'FLAG{%' LIMIT 1")"
BLIND="$(printf '%s' "$BLIND" | grep -oE 'FLAG\{[^}]*\}' | head -n1)"
[ -n "$UNION" ] && emit l2-fl-1 "$UNION"
[ -n "$BLIND" ] && emit l2-fl-2 "$BLIND"
exit 0
