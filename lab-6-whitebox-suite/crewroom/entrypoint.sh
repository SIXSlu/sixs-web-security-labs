#!/bin/sh
# ---------------------------------------------------------------------------
# CrewRoom deploy-time provisioning. The lab flags and the stationmaster's
# tap password are generated when the container starts so neither ever
# sits in the image layers or in version control. Runs as root (the depot
# seal is root-only by design); the wall and the supervisor bot then run
# as the crewroom account.
# ---------------------------------------------------------------------------
set -e

rand() { node -e "process.stdout.write(require('crypto').randomBytes(6).toString('hex'))"; }
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

# FLAG 1 is the stationmaster briefing - the wall hands it to a live
# admin tap, so it is exactly as protected as the session.
FLAG1="FLAG{crewroom_token_$(rand)}"
# FLAG 2 is the root-only depot seal - only the setuid helper reads it.
FLAG2="FLAG{crewroom_pollution_$(rand)}"

# The stationmaster's tap password: environment-only, minted per run.
SUPERVISOR_PASSWORD="$(node -e "process.stdout.write(require('crypto').randomBytes(16).toString('hex'))")"
export SUPERVISOR_PASSWORD

sixs_emit l6-crew-1 "$FLAG1"
sixs_emit l6-crew-2 "$FLAG2"

# Stationmaster briefing: readable through an admin tap only.
cat > /opt/crewroom/briefing.txt <<EOF
Station briefing, duty stationmaster -

Round trips on the heritage loop are capped at the posted limit this
week; the depot wants the archiving done before the last service. The
commissioning word for the verifier is:

$FLAG1

- Copperline Control
EOF
chown crewroom:crewroom /opt/crewroom/briefing.txt
chmod 640 /opt/crewroom/briefing.txt

# Depot seal: root-only, read only through the setuid helper.
echo "$FLAG2" > /opt/crewroom/flag_seal.txt
chown root:root /opt/crewroom/flag_seal.txt
chmod 400 /opt/crewroom/flag_seal.txt

# Fresh archive directory for this run.
rm -rf /opt/crewroom/backups
mkdir -p /opt/crewroom/backups
chown crewroom:crewroom /opt/crewroom/backups

# Drop privileges and serve in the foreground; the supervisor bot
# keeps its session warm alongside the wall.
exec setpriv --reuid=crewroom --regid=crewroom --clear-groups \
     sh -c 'node bot.js & exec node server.js'