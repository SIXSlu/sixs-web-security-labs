#!/bin/sh
# ---------------------------------------------------------------------------
# Build every SIXS lab image with host networking, then start the whole stack.
#
# Use this instead of `docker compose up --build -d` only on hosts whose Docker
# daemon cannot reach the internet from the default bridge network during a
# build. On a normal Docker install, `docker compose up --build -d` is enough.
#
# Images are tagged exactly as the central compose project (name: sixs-labs)
# expects, so the subsequent `docker compose up -d` reuses them without
# rebuilding.
# ---------------------------------------------------------------------------
set -e
cd "$(dirname "$0")"
ALLOW="--allow=network.host --network=host"

build() { echo ">> building $1"; docker build $ALLOW -t "$1" "$2"; }

build sixs-labs-atlas-api      lab-1-whitebox-suite/atlas-api
build sixs-labs-snipvault      lab-1-whitebox-suite/snipvault
build sixs-labs-reportsmith    lab-1-whitebox-suite/reportsmith
build sixs-labs-fleetledger-db lab-2-whitebox-suite/fleetledger/db
build sixs-labs-fleetledger    lab-2-whitebox-suite/fleetledger
build sixs-labs-caseforge      lab-2-whitebox-suite/caseforge
build sixs-labs-printbay       lab-2-whitebox-suite/printbay
build sixs-labs-papertrail     lab-3-papertrail/papertrail
build sixs-labs-intranet       lab-3-papertrail/intranet
build sixs-labs-harbordock-db  lab-4-harbordock/harbordock/db
build sixs-labs-provision      lab-4-harbordock/harbordock/db
build sixs-labs-harbordock     lab-4-harbordock/harbordock
build sixs-labs-dockops        lab-4-harbordock/dockops
docker build $ALLOW -t sixs-labs-tidegate -f lab-5-tidegate/tidegate/Dockerfile lab-5-tidegate
build sixs-labs-faredesk      lab-6-whitebox-suite/faredesk
build sixs-labs-trackside     lab-6-whitebox-suite/trackside
build sixs-labs-signalbox    lab-6-whitebox-suite/signalbox
build sixs-labs-crewroom     lab-6-whitebox-suite/crewroom

# atlas-db pulls postgres:16-alpine; compose fetches it on up.
docker compose up -d
docker compose ps
