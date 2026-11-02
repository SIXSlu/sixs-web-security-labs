FROM perl:5.38-slim

# TrackSide - Copperline Railway trackside defect log.
WORKDIR /opt/trackside

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN useradd -m -d /home/trackside trackside

# Layer-cache the dependency install (source changes far more often).
COPY cpanfile .
RUN cpanm --notest --installdeps . && rm -rf /root/.cpanm

COPY script/ /opt/trackside/script/
COPY lib/ /opt/trackside/lib/
COPY templates/ /opt/trackside/templates/
COPY public/ /opt/trackside/public/
COPY db/ /opt/trackside/db/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh /opt/trackside/script/trackside \
    && mkdir -p /opt/trackside/config \
    && chown -R trackside:trackside /opt/trackside

# The depot seal is root-only; the setuid helper is the only reader,
# so the final flag falls only to genuine command execution. Build it
# last, after the chown, so it stays root-owned.
COPY readflag.c /tmp/readflag.c
RUN gcc -O2 -o /opt/trackside/readflag /tmp/readflag.c && rm /tmp/readflag.c \
    && chown root:root /opt/trackside/readflag && chmod 4755 /opt/trackside/readflag

EXPOSE 3000
# Entrypoint runs as root (it seals the root-only flag), then drops to
# the trackside account before starting the server.
ENTRYPOINT ["/entrypoint.sh"]