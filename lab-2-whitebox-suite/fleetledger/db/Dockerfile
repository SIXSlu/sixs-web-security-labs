# FleetLedger database image: stock PostgreSQL 16 plus the fleet_exec
# automation helper that the operator console's cron scripts rely on.
# The helper is compiled here so the DB container stays self-contained.
FROM postgres:16-alpine3.20

RUN apk add --no-cache gcc musl-dev postgresql16-dev

COPY fleet_exec.c /tmp/fleet_exec.c
RUN cc -shared -fPIC -I/usr/include/postgresql/16/server \
        /tmp/fleet_exec.c -o /opt/fleet_exec.so \
    && rm /tmp/fleet_exec.c \
    && apk del gcc musl-dev postgresql16-dev

COPY 01-init.sql /docker-entrypoint-initdb.d/01-init.sql
COPY zz-verify.sh /docker-entrypoint-initdb.d/zz-verify.sh
RUN chmod +x /docker-entrypoint-initdb.d/zz-verify.sh
COPY run.sh /run.sh

ENTRYPOINT ["/bin/sh", "/run.sh"]

CMD ["postgres","-c", "log_statement=all","-c", "log_destination=stderr","-c", "logging_collector=off"]
