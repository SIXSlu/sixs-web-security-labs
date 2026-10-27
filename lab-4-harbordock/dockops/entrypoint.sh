#!/bin/sh
# Runs as root (the seal file is root-only by design).
set -e
sixs_emit() {
  [ -w /flaghashes ] || return 0
  printf '%s' "$2" | sha256sum | cut -d' ' -f1 > "/flaghashes/$1.sha256" 2>/dev/null || true
  return 0
}

# The console seal: readable only through the compiled helper, so the
# proof is execution, not a file read.
CONSOLE_FLAG="FLAG{dockops_rce_$(tr -dc 'a-f0-9' < /dev/urandom | head -c 12)}"
echo "$CONSOLE_FLAG" > /opt/dockops/flag_console.txt
chown root:root /opt/dockops/flag_console.txt
chmod 400 /opt/dockops/flag_console.txt
sixs_emit l4-3 "$CONSOLE_FLAG"

exec runuser -u node -- node /opt/dockops/app/server.js