#!/bin/bash

# Generate self-signed certificates for development/testing
# In production, use proper CA-signed certificates

CERT_DIR="./vault/certs"
mkdir -p "$CERT_DIR"

# Generate CA private key
openssl genrsa -out "$CERT_DIR/ca.key" 4096

# Generate CA certificate
openssl req -new -x509 -days 365 -key "$CERT_DIR/ca.key" -out "$CERT_DIR/ca.crt" -subj "/CN=Vault-CA"

# Generate Vault private key
openssl genrsa -out "$CERT_DIR/vault.key" 4096

# Create certificate signing request
openssl req -new -key "$CERT_DIR/vault.key" -out "$CERT_DIR/vault.csr" -subj "/CN=vault"

# Create certificate extensions file
cat > "$CERT_DIR/vault.ext" << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = vault
DNS.2 = localhost
IP.1 = 127.0.0.1
IP.2 = 172.20.0.2
EOF

# Generate Vault certificate
openssl x509 -req -in "$CERT_DIR/vault.csr" -CA "$CERT_DIR/ca.crt" -CAkey "$CERT_DIR/ca.key" -CAcreateserial -out "$CERT_DIR/vault.crt" -days 365 -extfile "$CERT_DIR/vault.ext"

# Set proper permissions
chmod 600 "$CERT_DIR/vault.key"
chmod 644 "$CERT_DIR/vault.crt"
chmod 644 "$CERT_DIR/ca.crt"

echo "Certificates generated successfully in $CERT_DIR"
echo "Remember to use proper CA-signed certificates in production!"