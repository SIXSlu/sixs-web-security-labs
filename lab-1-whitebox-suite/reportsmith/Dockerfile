FROM node:20-bookworm-slim
WORKDIR /opt/reportsmith

COPY package.json .
RUN npm install --omit=dev

COPY app/ /opt/reportsmith/app/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh \
    && chown -R node:node /opt/reportsmith

USER node
EXPOSE 3000
ENTRYPOINT ["/entrypoint.sh"]