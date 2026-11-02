#!/bin/sh
# Deploy-time provisioning: the deployment key and lab flags are generated
# when the container starts so they never sit in the image layers or in
# version control.
set -e

rand() { python3 -c "import secrets; print(secrets.token_hex(8))"; }
sixs_emit() {
  [ -w /flaghashes ] || return 0
  f="/flaghashes/$1.sha256"
  # Drop any previous hash first: a bare `>` only truncates, which a
  # leftover file owned by another uid refuses even in the 1777 dir.
  rm -f "$f" 2>/dev/null || true
  printf '%s' "$2" | sha256sum | cut -d' ' -f1 > "$f" 2>/dev/null \
    || echo "sixs_emit: could not publish $f; the verifier will miss this flag" >&2
  return 0
}

FLAG1="FLAG{snipvault_file_read_$(rand)}"
FLAG2="FLAG{snipvault_pickle_rce_$(rand)}"
sixs_emit l1-snip-1 "$FLAG1"
sixs_emit l1-snip-2 "$FLAG2"

mkdir -p /opt/snipvault/data
cat > /opt/snipvault/config.ini <<EOF
[auth]
secret_key = $(rand)$(rand)

[storage]
vault_dir = /opt/snipvault/data

[lab]
first_flag = ${FLAG1}
EOF

# the RCE flag is only readable by the service account
echo "${FLAG2}" > /home/snipvault/flag2.txt
chmod 600 /home/snipvault/flag2.txt

cd /opt/snipvault/app
exec gunicorn --workers 1 --threads 4 --bind 0.0.0.0:5000 --access-logfile - app:app