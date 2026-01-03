listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/vault/certs/vault.crt"
  tls_key_file  = "/vault/certs/vault.key"
}

storage "file" {
  path = "/vault/data"
}

# Enable the Vault UI
ui = true

# Set default and max lease TTLs
default_lease_ttl = "168h"  # 7 days
max_lease_ttl = "720h"      # 30 days

# API address
api_addr = "https://vault:8200"

# Disable memory locking (required for Docker)
disable_mlock = true

# Log level
log_level = "INFO"