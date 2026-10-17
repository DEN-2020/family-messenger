#!/usr/bin/env bash
# Family Messenger — Phase 0: Live Verification of E2EE Ciphertext in PostgreSQL + Backup & Restore
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== 1. Verifying Encrypted Events in PostgreSQL ==="
sudo -u postgres psql -d family_messenger_synapse -c "SELECT event_id, type, sender, room_id FROM events WHERE type IN ('m.room.encryption', 'm.room.encrypted') ORDER BY stream_ordering;"
sudo -u postgres psql -d family_messenger_synapse -c "SELECT left(json::text, 260) AS encrypted_event_json_sample FROM event_json WHERE event_id IN (SELECT event_id FROM events WHERE type = 'm.room.encrypted') LIMIT 2;"

echo "=== 2. Running Full Backup Script (backup.sh) ==="
"${SCRIPT_DIR}/backup.sh"

echo "=== 3. Running Full Restore Script (restore.sh) ==="
"${SCRIPT_DIR}/restore.sh" /var/backups/family-messenger/latest

echo "=== 4. Verifying Post-Restore Data & Healthcheck ==="
sudo -u postgres psql -d family_messenger_synapse -c "SELECT count(*) AS restored_encrypted_events FROM events WHERE type = 'm.room.encrypted';"
/usr/local/bin/family-messenger-healthcheck
