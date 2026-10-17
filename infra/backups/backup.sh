#!/usr/bin/env bash
# Family Messenger — Full Backup Script (PostgreSQL + Media + Signing Keys & Config)
set -euo pipefail

BACKUP_ROOT="${BACKUP_ROOT:-/var/backups/family-messenger}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
TARGET_DIR="${BACKUP_ROOT}/${TIMESTAMP}"

mkdir -p "${TARGET_DIR}"
chmod 700 "${BACKUP_ROOT}" "${TARGET_DIR}"

echo "[1/4] Dumping PostgreSQL database family_messenger_synapse..."
sudo -u postgres pg_dump -Fc -d family_messenger_synapse > "${TARGET_DIR}/synapse_db.dump"

echo "[2/4] Archiving Matrix Media Storage (/var/lib/matrix-synapse/media)..."
tar -czf "${TARGET_DIR}/synapse_media.tar.gz" -C /var/lib/matrix-synapse media

echo "[3/4] Archiving Matrix Synapse config and signing keys (/etc/matrix-synapse)..."
tar -czf "${TARGET_DIR}/synapse_etc.tar.gz" -C /etc matrix-synapse

echo "[4/4] Generating SHA-256 integrity manifest..."
(cd "${TARGET_DIR}" && sha256sum synapse_db.dump synapse_media.tar.gz synapse_etc.tar.gz > SHA256SUMS)
chmod 600 "${TARGET_DIR}"/*

ln -sfn "${TARGET_DIR}" "${BACKUP_ROOT}/latest"
echo "Backup completed successfully at: ${TARGET_DIR}"
ls -lh "${TARGET_DIR}"
