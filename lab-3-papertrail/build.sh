#!/bin/sh
# Pre-build this lab's images under the tags docker compose expects, using
# host networking. Use this instead of `docker compose up --build -d` on
# hosts where the daemon cannot reach the internet from the default bridge
# network during a build (otherwise plain `docker compose up --build -d`
# works fine).
set -e
cd "$(dirname "$0")"
ALLOW="--allow=network.host --network=host"

docker build $ALLOW -t sixs-lab3-papertrail ./papertrail
docker build $ALLOW -t sixs-lab3-intranet ./intranet

docker compose up -d
docker compose ps