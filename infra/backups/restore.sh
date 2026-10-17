#!/usr/bin/env bash
# Family Messenger — Full Restore & Verification Script
set -euo pipefail

BACKUP_DIR="${1:-/var/backups/family-messenger/latest}"

if [ ! -d "${BACKUP_DIR}" ]; then
    echo "ERROR: Backup directory not found: ${BACKUP_DIR}" >&2
    exit 1
fi

echo "[1/5] Verifying SHA-256 checksums in ${BACKUP_DIR}..."
(cd "${BACKUP_DIR}" && sha256sum -c SHA256SUMS)

echo "[2/5] Stopping matrix-synapse service before restore..."
systemctl stop matrix-synapse

echo "[3/5] Restoring PostgreSQL database family_messenger_synapse..."
sudo -u postgres pg_restore --clean --if-exists --no-owner --role=synapse_user -d family_messenger_synapse < "${BACKUP_DIR}/synapse_db.dump"

echo "[4/5] Restoring Matrix Media Storage and /etc/matrix-synapse..."
tar -xzf "${BACKUP_DIR}/synapse_media.tar.gz" -C /var/lib/matrix-synapse
chown -R matrix-synapse:matrix-synapse /var/lib/matrix-synapse/media
tar -xzf "${BACKUP_DIR}/synapse_etc.tar.gz" -C /etc

echo "[5/5] Starting matrix-synapse and verifying health..."
systemctl start matrix-synapse
for i in {1..30}; do
    if curl -fsS http://127.0.0.1:8008/health >/dev/null 2>&1; then
        echo "Restore complete and Matrix Synapse is healthy."
        exit 0
    fi
    sleep 1
done

echo "ERROR: Matrix Synapse failed health check after restore." >&2
exit 1
