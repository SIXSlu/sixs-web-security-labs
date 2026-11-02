FROM perl:5.38-slim

# SignalBox - Copperline Railway departure boards and signal-box console.
WORKDIR /opt/signalbox

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN useradd -m -d /home/signalbox signalbox

# Layer-cache the dependency install (source changes far more often).
COPY cpanfile .
RUN cpanm --notest --installdeps . && rm -rf /root/.cpanm

COPY script/ /opt/signalbox/script/
COPY lib/ /opt/signalbox/lib/
COPY templates/ /opt/signalbox/templates/
COPY public/ /opt/signalbox/public/
COPY db/ /opt/signalbox/db/
COPY bin/ /opt/signalbox/bin/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh /opt/signalbox/script/signalbox /opt/signalbox/bin/announce \
    && mkdir -p /opt/signalbox/logs \
    && chown -R signalbox:signalbox /opt/signalbox

# The box seal is root-only; the setuid helper is the only reader,
# so the final flag falls only to genuine command execution. Build it
# last, after the chown, so it stays root-owned.
COPY readflag.c /tmp/readflag.c
RUN gcc -O2 -o /opt/signalbox/readflag /tmp/readflag.c && rm /tmp/readflag.c \
    && chown root:root /opt/signalbox/readflag && chmod 4755 /opt/signalbox/readflag

EXPOSE 3000
# Entrypoint runs as root (it seals the root-only flag), then drops to
# the signalbox account before starting the server.
ENTRYPOINT ["/entrypoint.sh"]