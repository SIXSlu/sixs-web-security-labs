# HarborDock database: schema, app roles, demo rows. Flag values and
# the ops token are minted at runtime by the `provision` service (see
# docker-compose.yml) so a restart always gives you a fresh pair.
FROM postgres:16-alpine
COPY 01-init.sql /docker-entrypoint-initdb.d/01-init.sql