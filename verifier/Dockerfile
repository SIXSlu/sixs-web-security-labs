# SIXS flag verifier — serves the flag console and a yes/no verify oracle.
# Build context is the repo root so it can bundle the shared panel.
FROM python:3.12-alpine
WORKDIR /app
COPY verifier/app.py /app/app.py
COPY flag-console/index.html /app/index.html
ENV FLAG_DIR=/flaghashes PANEL=/app/index.html PORT=8099
EXPOSE 8099
CMD ["python3", "/app/app.py"]
