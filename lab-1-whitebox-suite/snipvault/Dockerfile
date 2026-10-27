FROM python:3.12-slim
WORKDIR /opt/snipvault
RUN useradd -m -d /home/snipvault snipvault

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ /opt/snipvault/app/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh \
    && mkdir -p /opt/snipvault/data \
    && chown -R snipvault:snipvault /opt/snipvault

USER snipvault
EXPOSE 5000
ENTRYPOINT ["/entrypoint.sh"]