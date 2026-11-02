#!/bin/sh
# ---------------------------------------------------------------------------
# SignalBox deploy-time provisioning. The lab flags and the signalman
# PIN are generated when the container starts so they never sit in the
# image layers or in version control. Runs as root (the box seal is
# root-only by design); the board then serves requests as the signalbox
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

# FLAG 1 is the board's commissioning seal - the tail logbox can be
# talked into reading the box's own configuration, and only that way.
FLAG1="FLAG{signalbox_open_$(rand)}"
# FLAG 2 is the root-only box seal - only the setuid helper reads it.
FLAG2="FLAG{signalbox_shell_$(rand)}"

# The signalman PIN unlocks the ops console (session).
SIGNALMAN_PIN="$(rand)$(rand)"

sixs_emit l6-sig-1 "$FLAG1"
sixs_emit l6-sig-2 "$FLAG2"

# Board configuration: the box reads its own seal + pin from here. Only
# the service account can read this file - the ops console shows none
# of it, the tail logbox was never supposed to either.
cat > /opt/signalbox/board.conf <<EOF
# Signal box board configuration - sealed by ops at commissioning.
# The ops console reads signalman_pin from here; nothing else may.
board_seal = $FLAG1
signalman_pin = $SIGNALMAN_PIN
EOF
chown signalbox:signalbox /opt/signalbox/board.conf
chmod 640 /opt/signalbox/board.conf

# Box seal: root-only, read only through the setuid helper.
echo "$FLAG2" > /opt/signalbox/flag_seal.txt
chown root:root /opt/signalbox/flag_seal.txt
chmod 400 /opt/signalbox/flag_seal.txt

# Fresh timetable + a couple of shift logs for this run.
rm -f /opt/signalbox/signalbox.db /opt/signalbox/hypnotoad.pid
perl /opt/signalbox/db/init.pl
chown signalbox:signalbox /opt/signalbox/signalbox.db
chmod 600 /opt/signalbox/signalbox.db
chown signalbox:signalbox /opt/signalbox/logs
chmod 750 /opt/signalbox/logs

cat > /opt/signalbox/logs/shift-morning.log <<EOF
[06:12] boxes lit, points normal, first pass of the day on the board
[08:44] token for the Millbrook branch given up, train accepted
[11:02] crossing keeper reports clear, no road hold-ups
EOF
cat > /opt/signalbox/logs/shift-afternoon.log <<EOF
[12:01] shift handover complete, board wiped and relaid
[15:20] excursion of six coaches banked up to Copperline Halt
[17:35] lighting-up time, lamp columns topped up
EOF
chown signalbox:signalbox /opt/signalbox/logs/*.log
chmod 640 /opt/signalbox/logs/*.log

# Drop privileges and serve in the foreground.
exec setpriv --reuid=signalbox --regid=signalbox --clear-groups \
     hypnotoad -f /opt/signalbox/script/signalbox