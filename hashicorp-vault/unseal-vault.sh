#!/bin/bash

# Unseal Vault using the keys from vault-init.json

set -e

echo "Unsealing Vault..."

# Extract the first 3 unseal keys from the JSON file
UNSEAL_KEY_1=$(cat vault-init.json | jq -r '.unseal_keys_b64[0]')
UNSEAL_KEY_2=$(cat vault-init.json | jq -r '.unseal_keys_b64[1]')
UNSEAL_KEY_3=$(cat vault-init.json | jq -r '.unseal_keys_b64[2]')

# Unseal Vault (need 3 keys)
echo "Using first unseal key..."
docker exec -e VAULT_SKIP_VERIFY=true vault vault operator unseal "$UNSEAL_KEY_1"

echo "Using second unseal key..."
docker exec -e VAULT_SKIP_VERIFY=true vault vault operator unseal "$UNSEAL_KEY_2"

echo "Using third unseal key..."
docker exec -e VAULT_SKIP_VERIFY=true vault vault operator unseal "$UNSEAL_KEY_3"

echo "Vault has been unsealed!"

# Check status
docker exec -e VAULT_SKIP_VERIFY=true vault vault status