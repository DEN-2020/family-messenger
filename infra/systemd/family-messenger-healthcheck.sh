#!/usr/bin/env bash
# Family Messenger — Automated Health Check Script (PostgreSQL + Synapse + Nginx HTTPS)
set -euo pipefail

# 1. Check PostgreSQL service and connectivity
systemctl is-active --quiet postgresql
sudo -u postgres psql -d family_messenger_synapse -tAc "SELECT 1;" | grep -qx "1"

# 2. Check Matrix Synapse service and local health endpoint
systemctl is-active --quiet matrix-synapse
SYNAPSE_HEALTH="$(curl -fsS --max-time 5 http://127.0.0.1:8008/health)"
if [ "${SYNAPSE_HEALTH}" != "OK" ]; then
    echo "Synapse health check returned unexpected response: ${SYNAPSE_HEALTH}" >&2
    exit 1
fi

# 3. Check Nginx service and TLS Client-Server API endpoint
systemctl is-active --quiet nginx
curl --cacert /etc/nginx/ssl/family-messenger/root-ca.crt -fsS --max-time 5 https://localhost:8443/_matrix/client/versions | grep -q "versions"

echo "OK: PostgreSQL, Matrix Synapse, and Nginx HTTPS are healthy."
