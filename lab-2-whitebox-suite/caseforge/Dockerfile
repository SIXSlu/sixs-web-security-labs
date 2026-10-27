FROM python:3.12-slim
WORKDIR /opt/caseforge
RUN useradd -m -d /home/caseforge caseforge

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ /opt/caseforge/app/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh \
    && chown -R caseforge:caseforge /opt/caseforge

USER caseforge
EXPOSE 5000
ENTRYPOINT ["/entrypoint.sh"]