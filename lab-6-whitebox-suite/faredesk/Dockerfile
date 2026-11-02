FROM perl:5.38-slim

# FareDesk - Copperline Railway ticket-counter kiosk backend.
WORKDIR /opt/faredesk

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN useradd -m -d /home/faredesk faredesk

# Layer-cache the dependency install (source changes far more often).
COPY cpanfile .
RUN cpanm --notest --installdeps . && rm -rf /root/.cpanm

COPY script/ /opt/faredesk/script/
COPY lib/ /opt/faredesk/lib/
COPY templates/ /opt/faredesk/templates/
COPY public/ /opt/faredesk/public/
COPY db/ /opt/faredesk/db/
COPY bin/ /opt/faredesk/bin/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh /opt/faredesk/script/faredesk /opt/faredesk/bin/spool \
    && chown -R faredesk:faredesk /opt/faredesk

# The counter seal is root-only; the setuid helper is the only reader,
# so the final flag falls only to genuine command execution. Build it
# last, after the chown, so it stays root-owned.
COPY readflag.c /tmp/readflag.c
RUN gcc -O2 -o /opt/faredesk/readflag /tmp/readflag.c && rm /tmp/readflag.c \
    && chown root:root /opt/faredesk/readflag && chmod 4755 /opt/faredesk/readflag

EXPOSE 3000
# Entrypoint runs as root (it seals the root-only flag), then drops to
# the faredesk account before starting the server.
ENTRYPOINT ["/entrypoint.sh"]