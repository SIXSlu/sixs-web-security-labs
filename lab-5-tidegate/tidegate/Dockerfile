FROM php:8.3-apache

# pdo_sqlite for the gateway database; xsl for the manifest field-mapping
# transform. gcc (shipped in the official PHP image) compiles the ops
# seal helper.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libsqlite3-dev libxslt1-dev \
    && docker-php-ext-install pdo_sqlite xsl \
    && rm -rf /var/lib/apt/lists/*

# Root-only seal reader: the final flag is root-owned and only this
# setuid helper can read it, so recovering it needs command execution,
# not a file read.
COPY tidegate/readflag.c /tmp/readflag.c
RUN mkdir -p /opt/tidegate \
    && gcc -O2 -o /opt/tidegate/readflag /tmp/readflag.c \
    && rm /tmp/readflag.c \
    && chown root:root /opt/tidegate/readflag \
    && chmod 4755 /opt/tidegate/readflag

COPY tidegate/app/ /var/www/html/
COPY tidegate/init_db.php /opt/tidegate/init_db.php
COPY tidegate/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh \
    && chown -R www-data:www-data /var/www/html

EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]
