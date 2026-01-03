#!/bin/bash

# Vault initialization and unseal script
# Run this after starting the containers

set -e

# Skip TLS verification for self-signed certificates
export VAULT_SKIP_VERIFY=true

echo "Waiting for Vault to be ready..."
sleep 30

# Check if Vault is already initialized
if docker-compose exec -T vault sh -c "VAULT_SKIP_VERIFY=true vault status" > /dev/null 2>&1; then
    echo "Vault is already initialized"
else
    echo "Initializing Vault..."
    
    # Initialize Vault with 5 key shares and 3 key threshold
    docker-compose exec -T vault sh -c "VAULT_SKIP_VERIFY=true vault operator init -key-shares=5 -key-threshold=3 -format=json" > vault-init.json
    
    echo "Vault initialized successfully!"
    echo "Unseal keys and root token saved to vault-init.json"
    echo "Please store this file securely and delete it from this location after backing up"
    
    # Extract unseal keys
    UNSEAL_KEY_1=$(cat vault-init.json | jq -r '.unseal_keys_b64[0]')
    UNSEAL_KEY_2=$(cat vault-init.json | jq -r '.unseal_keys_b64[1]')
    UNSEAL_KEY_3=$(cat vault-init.json | jq -r '.unseal_keys_b64[2]')
    
    # Unseal Vault
    echo "Unsealing Vault..."
    docker-compose exec -T vault sh -c "VAULT_SKIP_VERIFY=true vault operator unseal $UNSEAL_KEY_1"
    docker-compose exec -T vault sh -c "VAULT_SKIP_VERIFY=true vault operator unseal $UNSEAL_KEY_2"
    docker-compose exec -T vault sh -c "VAULT_SKIP_VERIFY=true vault operator unseal $UNSEAL_KEY_3"
    
    echo "Vault has been unsealed successfully!"
    
    # Login with root token
    ROOT_TOKEN=$(cat vault-init.json | jq -r '.root_token')
    docker-compose exec -T vault sh -c "VAULT_SKIP_VERIFY=true echo $ROOT_TOKEN | vault auth -"
    
    echo "Setting up basic auth methods and policies..."
    
    # Enable userpass auth method
    docker-compose exec -T vault sh -c "VAULT_SKIP_VERIFY=true vault auth enable userpass"
    
    # Create a basic admin policy
    docker-compose exec -T vault sh -c "VAULT_SKIP_VERIFY=true vault policy write admin-policy - <<EOF
path \"*\" {
  capabilities = [\"create\", \"read\", \"update\", \"delete\", \"list\", \"sudo\"]
}
EOF"
    
    # Create an admin user
    docker-compose exec -T vault sh -c "VAULT_SKIP_VERIFY=true vault write auth/userpass/users/admin password=admin123 policies=admin-policy"
    
    echo "Setup completed!"
    echo "You can now access Vault at https://localhost:8200"
    echo "Admin user: admin / admin123"
    echo "Root token: $ROOT_TOKEN"
fi