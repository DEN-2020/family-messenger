#!/usr/bin/env bash
# Family Messenger — Automated Self-Healing Health Check Script (PostgreSQL + Synapse + Nginx)
# Executed every 2 minutes by systemd timer (family-messenger-healthcheck.timer)
# Logs to systemd journal without exposing any secrets.
set -euo pipefail

recover_service() {
    local svc="$1"
    logger -t family-messenger-healthcheck "WARN: Service ${svc} is unhealthy; restarting..."
    systemctl restart "${svc}"
    sleep 2
    systemctl is-active --quiet "${svc}"
    logger -t family-messenger-healthcheck "INFO: Service ${svc} recovered successfully."
}

# 1. Check PostgreSQL service and connectivity
if ! systemctl is-active --quiet postgresql || ! sudo -u postgres psql -d family_messenger_synapse -tAc "SELECT 1;" | grep -qx "1"; then
    recover_service postgresql
fi

# 2. Check Matrix Synapse service and local health endpoint
if ! systemctl is-active --quiet matrix-synapse || [ "$(curl -fsS --max-time 5 http://127.0.0.1:8008/health || true)" != "OK" ]; then
    recover_service matrix-synapse
fi

# 3. Check Nginx service and Funnel/TLS backend endpoints
if ! systemctl is-active --quiet nginx || ! curl -fsS --max-time 5 http://127.0.0.1:8440/_matrix/client/versions | grep -q "versions"; then
    recover_service nginx
fi

echo "OK: PostgreSQL, Matrix Synapse, and Nginx Funnel/HTTPS endpoints are healthy."
