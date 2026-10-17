#!/usr/bin/env bash
# Family Messenger — Phase 0: Systemd Hardening & Healthcheck Timer Setup
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p /etc/systemd/system/matrix-synapse.service.d
tr -d '\r' < "${SCRIPT_DIR}/matrix-synapse-override.conf" > /etc/systemd/system/matrix-synapse.service.d/override.conf

tr -d '\r' < "${SCRIPT_DIR}/family-messenger-healthcheck.sh" > /usr/local/bin/family-messenger-healthcheck
chmod 755 /usr/local/bin/family-messenger-healthcheck

cat > /etc/systemd/system/family-messenger-healthcheck.service <<EOF
[Unit]
Description=Family Messenger Stack Health Check
After=postgresql.service matrix-synapse.service nginx.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/family-messenger-healthcheck
StandardOutput=journal
StandardError=journal
EOF

cat > /etc/systemd/system/family-messenger-healthcheck.timer <<EOF
[Unit]
Description=Run Family Messenger Health Check every 5 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
Unit=family-messenger-healthcheck.service

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now family-messenger-healthcheck.timer
systemctl start family-messenger-healthcheck.service
systemctl status family-messenger-healthcheck.timer --no-pager
