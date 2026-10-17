#!/usr/bin/env bash
# Family Messenger — Phase 0: PostgreSQL 16 Native Setup & Least-Privilege Provisioning
set -euo pipefail

SECRETS_DIR="/etc/matrix-synapse/secrets"
DB_NAME="family_messenger_synapse"
DB_USER="synapse_user"

mkdir -p "${SECRETS_DIR}"
chown root:matrix-synapse "${SECRETS_DIR}"
chmod 750 "${SECRETS_DIR}"

if [ ! -s "${SECRETS_DIR}/db_password" ]; then
    openssl rand -hex 24 > "${SECRETS_DIR}/db_password"
fi
chown root:matrix-synapse "${SECRETS_DIR}/db_password"
chmod 640 "${SECRETS_DIR}/db_password"

DB_PASS="$(tr -d '\r\n' < "${SECRETS_DIR}/db_password")"

# Ensure PostgreSQL listens only on 127.0.0.1 (local loopback only, never public)
PG_CONF="/etc/postgresql/16/main/postgresql.conf"
if grep -q "^#*listen_addresses" "${PG_CONF}"; then
    sed -i "s/^#*listen_addresses.*/listen_addresses = '127.0.0.1'/" "${PG_CONF}"
fi

systemctl enable postgresql
systemctl start postgresql

# Create or update least-privilege role
ROLE_EXISTS="$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'")"
if [ "${ROLE_EXISTS}" = "1" ]; then
    sudo -u postgres psql -v ON_ERROR_STOP=1 -c "ALTER ROLE ${DB_USER} WITH LOGIN PASSWORD '${DB_PASS}' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;"
else
    sudo -u postgres psql -v ON_ERROR_STOP=1 -c "CREATE ROLE ${DB_USER} WITH LOGIN PASSWORD '${DB_PASS}' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;"
fi

# Create Synapse database with required C collation and UTF8 encoding
DB_EXISTS="$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'")"
if [ "${DB_EXISTS}" != "1" ]; then
    sudo -u postgres psql -v ON_ERROR_STOP=1 -c "CREATE DATABASE ${DB_NAME} ENCODING 'UTF8' LC_COLLATE='C' LC_CTYPE='C' TEMPLATE=template0 OWNER ${DB_USER};"
fi

# Enforce least privilege on database and public schema
sudo -u postgres psql -v ON_ERROR_STOP=1 -d "${DB_NAME}" -c "REVOKE ALL ON DATABASE ${DB_NAME} FROM PUBLIC;"
sudo -u postgres psql -v ON_ERROR_STOP=1 -d "${DB_NAME}" -c "GRANT CONNECT, TEMPORARY ON DATABASE ${DB_NAME} TO ${DB_USER};"
sudo -u postgres psql -v ON_ERROR_STOP=1 -d "${DB_NAME}" -c "REVOKE CREATE ON SCHEMA public FROM PUBLIC;"
sudo -u postgres psql -v ON_ERROR_STOP=1 -d "${DB_NAME}" -c "GRANT USAGE, CREATE ON SCHEMA public TO ${DB_USER};"

echo "=== PostgreSQL Verification ==="
sudo -u postgres psql -c "\du ${DB_USER}"
sudo -u postgres psql -c "SELECT datname, pg_encoding_to_char(encoding), datcollate, datctype FROM pg_database WHERE datname='${DB_NAME}';"
PGPASSWORD="${DB_PASS}" psql -h 127.0.0.1 -U "${DB_USER}" -d "${DB_NAME}" -c "SELECT current_user, current_database(), version();"
