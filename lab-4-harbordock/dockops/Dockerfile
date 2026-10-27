# Full image (not -slim): the seal helper is compiled in the same build.
FROM node:20
WORKDIR /opt/dockops

COPY package.json .
RUN npm install --omit=dev

COPY readflag.c /tmp/readflag.c
RUN gcc -o /usr/local/bin/readflag /tmp/readflag.c \
    && rm /tmp/readflag.c \
    && chmod 4755 /usr/local/bin/readflag \
    && chown root:root /usr/local/bin/readflag

COPY app/ /opt/dockops/app/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3000
ENTRYPOINT ["/entrypoint.sh"]