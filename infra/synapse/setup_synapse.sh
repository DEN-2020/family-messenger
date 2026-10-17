#!/usr/bin/env bash
# Family Messenger — Phase 0: Matrix Synapse Configuration & Hardening Script
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRETS_DIR="/etc/matrix-synapse/secrets"
CONF_DIR="/etc/matrix-synapse/conf.d"
MEDIA_DIR="/var/lib/matrix-synapse/media"

# IMPORTANT: Temporary server_name for Phase 0 testing ONLY.
# Do NOT create permanent family accounts until final domain is chosen.
SERVER_NAME="${SYNAPSE_SERVER_NAME:-test.family.internal}"

mkdir -p "${SECRETS_DIR}" "${CONF_DIR}" "${MEDIA_DIR}"
chown root:matrix-synapse "${SECRETS_DIR}"
chmod 750 "${SECRETS_DIR}"

for secret_name in registration_shared_secret macaroon_secret_key form_secret; do
    if [ ! -s "${SECRETS_DIR}/${secret_name}" ]; then
        openssl rand -hex 32 > "${SECRETS_DIR}/${secret_name}"
    fi
    chown root:matrix-synapse "${SECRETS_DIR}/${secret_name}"
    chmod 640 "${SECRETS_DIR}/${secret_name}"
done

DB_PASS="$(tr -d '\r\n' < "${SECRETS_DIR}/db_password")"
REG_SECRET="$(tr -d '\r\n' < "${SECRETS_DIR}/registration_shared_secret")"
MACAROON_SECRET="$(tr -d '\r\n' < "${SECRETS_DIR}/macaroon_secret_key")"
FORM_SECRET="$(tr -d '\r\n' < "${SECRETS_DIR}/form_secret")"

# Install base homeserver.yaml (strip CRLF if mounted from Windows)
tr -d '\r' < "${SCRIPT_DIR}/homeserver.yaml" > /etc/matrix-synapse/homeserver.yaml
chown root:matrix-synapse /etc/matrix-synapse/homeserver.yaml
chmod 640 /etc/matrix-synapse/homeserver.yaml

# Configure server_name.yaml
cat > "${CONF_DIR}/server_name.yaml" <<EOF
# Temporary Phase 0 test server_name.
# WARNING: Must be replaced with permanent domain BEFORE creating real family accounts.
server_name: "${SERVER_NAME}"
public_baseurl: "https://localhost:8443/"
EOF

# Configure report_stats.yaml
cat > "${CONF_DIR}/report_stats.yaml" <<EOF
report_stats: false
EOF

# Configure secrets & PostgreSQL connection in protected file (0640 root:matrix-synapse)
cat > "${CONF_DIR}/secrets.yaml" <<EOF
database:
  name: psycopg2
  args:
    user: synapse_user
    password: "${DB_PASS}"
    database: family_messenger_synapse
    host: 127.0.0.1
    port: 5432
    cp_min: 5
    cp_max: 10

registration_shared_secret: "${REG_SECRET}"
macaroon_secret_key: "${MACAROON_SECRET}"
form_secret: "${FORM_SECRET}"
EOF

chown root:matrix-synapse "${CONF_DIR}"/*.yaml
chmod 640 "${CONF_DIR}/secrets.yaml"
chmod 644 "${CONF_DIR}/server_name.yaml" "${CONF_DIR}/report_stats.yaml"

# Protect signing key and media storage
chown matrix-synapse:matrix-synapse /etc/matrix-synapse/homeserver.signing.key
chmod 600 /etc/matrix-synapse/homeserver.signing.key
chown -R matrix-synapse:matrix-synapse /var/lib/matrix-synapse
chmod 750 /var/lib/matrix-synapse "${MEDIA_DIR}"

# Remove default SQLite database if present so only PostgreSQL is used
rm -f /var/lib/matrix-synapse/homeserver.db /var/lib/matrix-synapse/homeserver.db-shm /var/lib/matrix-synapse/homeserver.db-wal

systemctl enable matrix-synapse
systemctl restart matrix-synapse

echo "Waiting for Matrix Synapse health endpoint on http://127.0.0.1:8008/health ..."
for i in {1..30}; do
    if curl -fsS http://127.0.0.1:8008/health >/dev/null 2>&1; then
        echo "Matrix Synapse is healthy: $(curl -fsS http://127.0.0.1:8008/health)"
        exit 0
    fi
    sleep 1
done

echo "ERROR: Matrix Synapse did not become healthy in time." >&2
journalctl -u matrix-synapse -n 50 --no-pager
exit 1
