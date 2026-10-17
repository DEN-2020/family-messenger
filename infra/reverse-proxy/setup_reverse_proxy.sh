#!/usr/bin/env bash
# Family Messenger — Phase 0: Local Private PKI & Nginx HTTPS Setup
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSL_DIR="/etc/nginx/ssl/family-messenger"
PUBLIC_CA_EXPORT="${SCRIPT_DIR}/certs/family-messenger-root-ca.crt"

mkdir -p "${SSL_DIR}" "${SCRIPT_DIR}/certs"
chmod 700 "${SSL_DIR}"

# 1. Generate Local Root CA (if not already present)
if [ ! -s "${SSL_DIR}/root-ca.key" ] || [ ! -s "${SSL_DIR}/root-ca.crt" ]; then
    echo "Generating Family Messenger Local Root CA..."
    openssl genrsa -out "${SSL_DIR}/root-ca.key" 4096
    openssl req -x509 -new -nodes -key "${SSL_DIR}/root-ca.key" -sha256 -days 3650 \
        -subj "/C=FI/O=Family Messenger Private PKI/CN=Family Messenger Test Root CA" \
        -addext "basicConstraints=critical,CA:TRUE,pathlen:0" \
        -addext "keyUsage=critical,keyCertSign,cRLSign" \
        -out "${SSL_DIR}/root-ca.crt"
    chmod 600 "${SSL_DIR}/root-ca.key"
    chmod 644 "${SSL_DIR}/root-ca.crt"
fi

# 2. Generate Server TLS Certificate signed by Root CA with SANs for localhost, 127.0.0.1, 192.168.2.122, test.family.internal
LAN_IP="${WINDOWS_LAN_IP:-192.168.2.122}"
if [ ! -s "${SSL_DIR}/server.key" ] || ! openssl x509 -in "${SSL_DIR}/server.crt" -noout -ext subjectAltName 2>/dev/null | grep -q "${LAN_IP}"; then
    echo "Generating Server TLS Certificate signed by Root CA (with LAN IP ${LAN_IP})..."
    openssl genrsa -out "${SSL_DIR}/server.key" 2048
    openssl req -new -key "${SSL_DIR}/server.key" \
        -subj "/C=FI/O=Family Messenger/CN=${LAN_IP}" \
        -out "${SSL_DIR}/server.csr"

    cat > "${SSL_DIR}/server-ext.cnf" <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=@alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = test.family.internal
IP.1 = 127.0.0.1
IP.2 = ${LAN_IP}
EOF

    openssl x509 -req -in "${SSL_DIR}/server.csr" \
        -CA "${SSL_DIR}/root-ca.crt" -CAkey "${SSL_DIR}/root-ca.key" -CAcreateserial \
        -out "${SSL_DIR}/server.crt" -days 825 -sha256 \
        -extfile "${SSL_DIR}/server-ext.cnf"

    cat "${SSL_DIR}/server.crt" "${SSL_DIR}/root-ca.crt" > "${SSL_DIR}/server-fullchain.crt"
    chmod 600 "${SSL_DIR}/server.key"
    chmod 644 "${SSL_DIR}/server.crt" "${SSL_DIR}/server-fullchain.crt"
fi

# Export ONLY the public Root CA certificate so the client/OS can verify TLS strictly (no private keys in repo)
cp "${SSL_DIR}/root-ca.crt" "${PUBLIC_CA_EXPORT}"
chmod 644 "${PUBLIC_CA_EXPORT}"

# Install Root CA into Ubuntu trust store as well
cp "${SSL_DIR}/root-ca.crt" /usr/local/share/ca-certificates/family-messenger-root-ca.crt
update-ca-certificates >/dev/null

# 3. Configure Nginx without touching port 80 (used by Windows System HTTP.sys)
rm -f /etc/nginx/sites-enabled/default
tr -d '\r' < "${SCRIPT_DIR}/nginx-matrix.conf" > /etc/nginx/sites-available/family-messenger-matrix.conf
ln -sf /etc/nginx/sites-available/family-messenger-matrix.conf /etc/nginx/sites-enabled/family-messenger-matrix.conf

nginx -t
systemctl enable nginx
systemctl restart nginx

echo "=== Verifying HTTPS Reverse Proxy with strict CA verification ==="
curl --cacert "${SSL_DIR}/root-ca.crt" -fsS https://localhost:8443/health
echo ""
curl --cacert "${SSL_DIR}/root-ca.crt" -fsS https://localhost:8443/_matrix/client/versions
echo ""
