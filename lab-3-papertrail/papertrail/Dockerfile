FROM python:3.12-slim
WORKDIR /opt/papertrail
RUN useradd -m -d /home/papertrail papertrail

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ /opt/papertrail/app/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh \
    && mkdir -p /opt/papertrail \
    && chown -R papertrail:papertrail /opt/papertrail

USER papertrail
EXPOSE 5000
ENTRYPOINT ["/entrypoint.sh"]