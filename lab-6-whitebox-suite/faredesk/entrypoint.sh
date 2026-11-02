#!/bin/sh
# ---------------------------------------------------------------------------
# FareDesk deploy-time provisioning. The lab flags are generated when the
# container starts so they never sit in the image layers or in version
# control. Runs as root (the counter seal is root-only by design); the
# kiosk then serves requests as the faredesk account.
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

# FLAG 1 is the ops banner the admin console renders - reachable only
# through a forged counter-SSO session.
FLAG1="FLAG{faredesk_session_$(rand)}"
# FLAG 2 sits in a file the formula engine can be talked into reading.
FLAG2="FLAG{faredesk_eval_$(rand)}"
# FLAG 3 is the root-only counter seal - only the setuid helper reads it,
# so it falls only to real command execution.
FLAG3="FLAG{faredesk_pipe_$(rand)}"

sixs_emit l6-fare-1 "$FLAG1"
sixs_emit l6-fare-2 "$FLAG2"
sixs_emit l6-fare-3 "$FLAG3"

# Ops banner shown on the session-gated staff console.
echo "$FLAG1" > /opt/faredesk/ops_banner.txt
chown faredesk:faredesk /opt/faredesk/ops_banner.txt
chmod 640 /opt/faredesk/ops_banner.txt

# Formula-engine payoff: only the service account can read this.
echo "$FLAG2" > /opt/faredesk/flag_eval.txt
chown faredesk:faredesk /opt/faredesk/flag_eval.txt
chmod 600 /opt/faredesk/flag_eval.txt

# Counter seal: root-only, read only through the setuid helper.
echo "$FLAG3" > /opt/faredesk/flag_seal.txt
chown root:root /opt/faredesk/flag_seal.txt
chmod 400 /opt/faredesk/flag_seal.txt

# Fresh fare/booking database for this run.
rm -f /opt/faredesk/faredesk.db /opt/faredesk/hypnotoad.pid
perl /opt/faredesk/db/init.pl
chown faredesk:faredesk /opt/faredesk/faredesk.db
chmod 600 /opt/faredesk/faredesk.db

# Drop privileges and serve in the foreground.
exec setpriv --reuid=faredesk --regid=faredesk --clear-groups \
     hypnotoad -f /opt/faredesk/script/faredesk