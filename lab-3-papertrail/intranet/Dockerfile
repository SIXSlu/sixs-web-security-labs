# The full image (not -slim) so security tooling can ship a compiled
# helper in the same build.
FROM python:3.12
WORKDIR /opt/intranet

RUN useradd -m -d /home/intranet intranet

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY readflag.c /tmp/readflag.c
RUN gcc -o /opt/intranet/readflag /tmp/readflag.c \
    && rm /tmp/readflag.c \
    && chmod 4755 /opt/intranet/readflag \
    && chown root:root /opt/intranet/readflag

COPY app/ /opt/intranet/app/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 9000
ENTRYPOINT ["/entrypoint.sh"]