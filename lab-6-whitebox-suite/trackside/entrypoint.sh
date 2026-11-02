#!/bin/sh
# ---------------------------------------------------------------------------
# TrackSide deploy-time provisioning. The lab flags and the staff import
# token are generated when the container starts so they never sit in the
# image layers or in version control. Runs as root (the depot seal is
# root-only by design); the log then serves requests as the trackside
# account.
# ---------------------------------------------------------------------------
set -e

rand() { perl -e 'open my $f, "<", "/dev/urandom"; read($f, my $b, 6); print unpack("H*", $b);'; }
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

# FLAG 1 is the match-engine commissioning seal - the match engine can
# be talked into reading it, but only through real pattern control.
FLAG1="FLAG{trackside_regex_$(rand)}"
# FLAG 2 is the root-only depot seal - only the setuid helper reads it.
FLAG2="FLAG{trackside_yaml_$(rand)}"

# The staff import token authenticates the shift-handover feed.
IMPORT_TOKEN="$(rand)$(rand)"

sixs_emit l6-track-1 "$FLAG1"
sixs_emit l6-track-2 "$FLAG2"

# Match-engine payoff: only the service account can read this.
echo "$FLAG1" > /opt/trackside/flag_regex.txt
chown trackside:trackside /opt/trackside/flag_regex.txt
chmod 600 /opt/trackside/flag_regex.txt

# Handover-feed credential: the match engine's command execution is
# the intended way to lift it.
mkdir -p /opt/trackside/config
echo "$IMPORT_TOKEN" > /opt/trackside/config/import.key
chown trackside:trackside /opt/trackside/config/import.key
chmod 600 /opt/trackside/config/import.key

# Depot seal: root-only, read only through the setuid helper.
echo "$FLAG2" > /opt/trackside/flag_seal.txt
chown root:root /opt/trackside/flag_seal.txt
chmod 400 /opt/trackside/flag_seal.txt

# Fresh defect log for this run.
rm -f /opt/trackside/trackside.db /opt/trackside/hypnotoad.pid
perl /opt/trackside/db/init.pl
chown trackside:trackside /opt/trackside/trackside.db
chmod 600 /opt/trackside/trackside.db

# Drop privileges and serve in the foreground.
exec setpriv --reuid=trackside --regid=trackside --clear-groups \
     hypnotoad -f /opt/trackside/script/trackside