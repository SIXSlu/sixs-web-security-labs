#!/bin/sh
# Wrapper entrypoint for the FleetLedger database container.
#
# The RCE proof flag is generated fresh at every container start and only
# ever exists in the postgres process environment. There is no SQL view or
# table that contains it: it is only reachable through command execution.
set -e

FLAG="FLAG{fleetledger_udf_$(tr -dc a-f0-9 < /dev/urandom | head -c 12)}"
export FLEET_DB_FLAG="$FLAG"
mkdir -p /flaghashes 2>/dev/null || true
chmod 0777 /flaghashes 2>/dev/null || true
printf '%s' "$FLAG" | sha256sum | cut -d' ' -f1 > /flaghashes/l2-fl-3.sha256 2>/dev/null || true

exec docker-entrypoint.sh postgres