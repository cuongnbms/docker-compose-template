# HashiCorp Vault Production Docker Setup

This setup provides a production-ready HashiCorp Vault deployment using Docker Compose with file storage backend.

## Features

- 🔒 **Secure Configuration**: TLS encryption, proper certificates
- 💾 **Persistent Storage**: File-based storage with Docker volumes
- 📊 **Health Checks**: Built-in health monitoring
- 🛡️ **Security**: Proper permissions and network isolation
- 📈 **Monitoring**: Telemetry and logging configuration
- 🚀 **Simple Deployment**: Single-container setup for ease of use

## Quick Start

1. **Generate Certificates** (for development/testing):
   ```bash
   chmod +x generate-certs.sh
   ./generate-certs.sh
   ```

2. **Start the Stack**:
   ```bash
   docker-compose up -d
   ```

3. **Initialize Vault**:
   ```bash
   chmod +x init-vault.sh
   ./init-vault.sh
   ```

4. **Access Vault**:
   - Vault UI: https://localhost:8200

## Configuration

### Vault Configuration
- **Storage**: File-based storage for simplicity and reliability
- **TLS**: Enabled with custom certificates
- **UI**: Enabled for web management
- **Lease TTL**: 7 days default, 30 days maximum

## Production Considerations

### Security
1. **Certificates**: Replace self-signed certs with CA-signed certificates
2. **Secrets**: Use Docker secrets or external secret management
3. **Network**: Implement proper firewall rules
4. **Access**: Configure proper ACLs and policies

### Scaling & High Availability
1. **Load Balancer**: Add load balancer for high availability
2. **External Storage**: Consider external storage solutions for HA
3. **Backup Strategy**: Implement regular data backups
4. **Monitoring**: Set up comprehensive monitoring

### Monitoring & Maintenance
1. **Metrics**: Configure Prometheus integration
2. **Logs**: Set up centralized logging
3. **Backups**: Implement regular file system backups
4. **Alerts**: Set up monitoring alerts

## Commands

### View Logs
```bash
# Vault logs
docker-compose logs -f vault
```

### Vault Operations
```bash
# Status
docker-compose exec vault vault status

# Unseal (if needed)
docker-compose exec vault vault operator unseal <unseal-key>

# Create token
docker-compose exec vault vault token create
```

## Directory Structure

```
vault/
├── docker-compose.yaml
├── generate-certs.sh
├── init-vault.sh
├── vault/
│   ├── config/
│   │   └── vault.hcl
│   ├── certs/
│   └── logs/
└── README.md
```

## Environment Variables

- `VAULT_ADDR`: Vault server address
- `VAULT_API_ADDR`: API address for Vault
- `VAULT_SKIP_VERIFY`: Skip TLS verification (dev only)

## Troubleshooting

### Vault Sealed
If Vault becomes sealed, unseal it with:
```bash
docker-compose exec vault vault operator unseal <unseal-key-1>
docker-compose exec vault vault operator unseal <unseal-key-2>
docker-compose exec vault vault operator unseal <unseal-key-3>
```

### Certificate Issues
Regenerate certificates:
```bash
./generate-certs.sh
docker-compose restart vault
```

### Data Persistence
Vault data is stored in the `vault-data` Docker volume. To backup:
```bash
docker run --rm -v vault_vault-data:/data -v $(pwd):/backup alpine tar czf /backup/vault-backup.tar.gz -C /data .
```

## Security Best Practices

1. **Never use default passwords in production**
2. **Rotate certificates regularly**
3. **Use proper RBAC policies**
4. **Enable audit logging**
5. **Regular security updates**
6. **Network segmentation**
7. **Monitor access logs**

## Support

For HashiCorp Vault documentation and support:
- [Vault Documentation](https://www.vaultproject.io/docs)
- [Production Hardening Guide](https://learn.hashicorp.com/tutorials/vault/production-hardening)