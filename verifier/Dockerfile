# SIXS flag verifier — serves the flag console, a yes/no verify oracle and
# the repo / per-lab READMEs (allowlisted in app.py) for the panel's links.
# Build context is the repo root so it can bundle the shared panel.
FROM python:3.12-alpine
WORKDIR /app
COPY verifier/app.py /app/app.py
COPY flag-console/index.html /app/index.html
COPY README.md /readmes/README.md
COPY lab-1-whitebox-suite/README.md /readmes/lab-1-whitebox-suite/README.md
COPY lab-2-whitebox-suite/README.md /readmes/lab-2-whitebox-suite/README.md
COPY lab-3-papertrail/README.md /readmes/lab-3-papertrail/README.md
COPY lab-4-harbordock/README.md /readmes/lab-4-harbordock/README.md
COPY lab-5-tidegate/README.md /readmes/lab-5-tidegate/README.md
ENV FLAG_DIR=/flaghashes PANEL=/app/index.html PORT=8099 README_DIR=/readmes
EXPOSE 8099
CMD ["python3", "/app/app.py"]
