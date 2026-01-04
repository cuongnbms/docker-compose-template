#!/bin/bash

# Backup script for Vault with file storage backend
# Can be run via cron for regular backups

set -e

export VAULT_ADDR="https://localhost:8200"
export VAULT_SKIP_VERIFY=true
BACKUP_DIR="./vault/backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="vault-backup-${TIMESTAMP}.tar.gz"

echo "Starting Vault backup process..."

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Check if Vault container is running
if ! docker ps | grep -q "vault"; then
    echo "Error: Vault container is not running!"
    exit 1
fi

# For file storage backend, we backup the entire data directory
echo "Creating backup of Vault data directory..."
tar -czf "${BACKUP_DIR}/${BACKUP_FILE}" -C ./vault data/

echo "Backup saved to: ${BACKUP_DIR}/${BACKUP_FILE}"

# Clean up old backups (keep last 7 days)
find "$BACKUP_DIR" -name "vault-snapshot-*.snap" -type f -mtime +7 -delete

echo "Backup process completed successfully!"