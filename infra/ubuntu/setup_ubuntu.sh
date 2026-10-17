#!/usr/bin/env bash
# Family Messenger — Phase 0: Ubuntu 24.04 Native Host Setup (No Docker)
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "[1/4] Verifying systemd is PID 1..."
if [ "$(ps -p 1 -o comm=)" != "systemd" ]; then
    echo "ERROR: systemd is not PID 1. Enable systemd=true in /etc/wsl.conf" >&2
    exit 1
fi

echo "[2/4] Installing core packages and official Matrix.org keyring..."
apt-get update -qq
apt-get install -y -qq lsb-release wget apt-transport-https ca-certificates curl gnupg openssl jq

if [ ! -f /usr/share/keyrings/matrix-org-archive-keyring.gpg ]; then
    wget -qO /usr/share/keyrings/matrix-org-archive-keyring.gpg https://packages.matrix.org/debian/matrix-org-archive-keyring.gpg
fi

CODENAME="$(lsb_release -cs)"
echo "deb [signed-by=/usr/share/keyrings/matrix-org-archive-keyring.gpg] https://packages.matrix.org/debian/ ${CODENAME} main" > /etc/apt/sources.list.d/matrix-org.list

echo "[3/4] Installing PostgreSQL 16, Nginx, and Matrix Synapse..."
echo "matrix-synapse-py3 matrix-synapse/server-name string test.family.internal" | debconf-set-selections
echo "matrix-synapse-py3 matrix-synapse/report-stats boolean false" | debconf-set-selections
apt-get update -qq
apt-get install -y -qq postgresql postgresql-contrib nginx matrix-synapse-py3

echo "[4/4] Verifying no Docker/Podman services are installed or active..."
if systemctl is-active --quiet docker 2>/dev/null || systemctl is-active --quiet podman 2>/dev/null; then
    echo "WARNING: Container runtime detected! This setup strictly prohibits Docker/Podman." >&2
    exit 1
fi

echo "Ubuntu native packages installed successfully."
