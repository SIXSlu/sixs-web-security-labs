#!/bin/sh
# Pre-build this lab's image under the tag docker compose expects, using
# host networking. Use this instead of `docker compose up --build -d` on
# hosts where the daemon cannot reach the internet from the default bridge
# network during a build (otherwise plain `docker compose up --build -d`
# works fine).
set -e
cd "$(dirname "$0")"
ALLOW="--allow=network.host --network=host"

docker build $ALLOW -t sixs-lab5-tidegate -f tidegate/Dockerfile .

docker compose up -d
docker compose ps
