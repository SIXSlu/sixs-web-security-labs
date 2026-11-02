FROM node:20-slim

# CrewRoom - Copperline Railway crew notice wall (Node 20 + Express).
WORKDIR /opt/crewroom

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN useradd -m -d /home/crewroom crewroom

# Layer-cache the dependency install (source changes far more often).
COPY package.json .
RUN npm install --omit=dev && npm cache clean --force

COPY server.js bot.js ./
COPY public/ /opt/crewroom/public/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh \
    && chown -R crewroom:crewroom /opt/crewroom

# The handover archiver lives on PATH where the console expects it.
COPY bin/crewroom-backup /usr/local/bin/crewroom-backup
RUN chmod 755 /usr/local/bin/crewroom-backup

# The depot seal is root-only; the setuid helper is the only reader,
# so the final flag falls only to genuine command execution. Build it
# last, after the chown, so it stays root-owned.
COPY readflag.c /tmp/readflag.c
RUN gcc -O2 -o /opt/crewroom/readflag /tmp/readflag.c && rm /tmp/readflag.c \
    && chown root:root /opt/crewroom/readflag && chmod 4755 /opt/crewroom/readflag

EXPOSE 3000
# Entrypoint runs as root (it mints the flags and the stationmaster's
# password), then drops to the crewroom account before starting the
# wall and the supervisor bot.
ENTRYPOINT ["/entrypoint.sh"]