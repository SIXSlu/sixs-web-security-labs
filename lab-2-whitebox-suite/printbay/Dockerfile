FROM php:8.3-apache

# The preview cache and shop settings live in SQLite.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/* \
    && docker-php-ext-install pdo_sqlite

COPY app/ /var/www/html/
COPY init_db.php /opt/printbay/init_db.php
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh \
    && mkdir -p /opt/printbay \
    && chown -R www-data:www-data /var/www/html /opt/printbay

EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]