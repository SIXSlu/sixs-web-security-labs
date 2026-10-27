#!/bin/sh
# Wrapper entrypoint for the ATLAS database container.
#
# The RCE proof flag is generated fresh at every container start and only
# ever exists in the postgres process environment. There is no SQL
# function that can read it: it is only reachable through command
# execution.
set -e

FLAG="FLAG{atlas_rce_$(tr -dc a-f0-9 < /dev/urandom | head -c 12)}"
export ATLAS_DB_FLAG="$FLAG"
mkdir -p /flaghashes 2>/dev/null || true
chmod 0777 /flaghashes 2>/dev/null || true
printf '%s' "$FLAG" | sha256sum | cut -d' ' -f1 > /flaghashes/l1-atlas-3.sha256 2>/dev/null || true

exec docker-entrypoint.sh postgres