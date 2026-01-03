#!/bin/bash

# Backup script for Vault snapshots
# Can be run via cron for regular backups

set -e

VAULT_ADDR="https://vault:8200"
VAULT_SKIP_VERIFY=true
BACKUP_DIR="/vault/backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="vault-snapshot-${TIMESTAMP}.snap"

echo "Starting Vault backup process..."

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Create snapshot
vault operator raft snapshot save "${BACKUP_DIR}/${BACKUP_FILE}"

echo "Backup saved to: ${BACKUP_DIR}/${BACKUP_FILE}"

# Clean up old backups (keep last 7 days)
find "$BACKUP_DIR" -name "vault-snapshot-*.snap" -type f -mtime +7 -delete

echo "Backup process completed successfully!"