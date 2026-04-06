# Errbit Docker Setup

Self-hosted error catcher built on Rails + MongoDB. Compatible with Airbrake API v3.

## Quick Start

1. **Configure environment**:
   ```bash
   cp .env.example .env   # or edit .env directly
   # Generate a secret key:
   openssl rand -hex 64
   ```

2. **Start the stack** (first run):
   ```bash
   # Ensure ERRBIT_BOOTSTRAP=true in .env
   docker compose up -d
   ```

3. **Disable bootstrap** after first run:
   ```bash
   # Set ERRBIT_BOOTSTRAP=false in .env, then restart
   docker compose restart errbit
   ```

4. **Access Errbit**: http://errbit.localhost.dev:8080
   - Default login: `admin@errbit.example.com` / `password`

## Services

| Service | Image | Purpose |
|---------|-------|---------|
| `mongo` | mongo:8 | Error data storage |
| `errbit` | Custom (built from Dockerfile) | Errbit application |

## Environment Variables

### Core

| Variable | Description | Default |
|----------|-------------|---------|
| `ERRBIT_HOST` | Hostname for the Errbit instance | `errbit.localhost.dev` |
| `ERRBIT_PORT` | Published port on the host | `8080` |
| `ERRBIT_BOOTSTRAP` | Run DB bootstrap on startup (indexes + admin user) | `true` |
| `SECRET_KEY_BASE` | Rails secret key (generate with `openssl rand -hex 64`) | - |
| `ERRBIT_ADMIN_EMAIL` | Admin email created during bootstrap | `admin@errbit.example.com` |
| `ERRBIT_ADMIN_PASSWORD` | Admin password created during bootstrap | `password` |

### Email Notifications

| Variable | Description | Default |
|----------|-------------|---------|
| `ERRBIT_EMAIL_FROM` | Sender address for notification emails | `errbit@example.com` |
| `ERRBIT_EMAIL_AT_NOTICES` | Send email at these notice counts | `[1,10,100]` |
| `ERRBIT_NOTIFY_AT_NOTICES` | Trigger notifications at these counts | `[0]` |

### OAuth (Optional)

GitHub and Google OAuth can be enabled by setting `GITHUB_AUTHENTICATION=true` or `GOOGLE_AUTHENTICATION=true` and providing the corresponding client ID and secret.

## Traefik Integration

The compose file includes Traefik labels. Update the `Host` rule in `docker-compose.yml` to match your domain:

```yaml
- "traefik.http.routers.errbit.rule=Host(`errbit.example.com`)"
```

Requires the external `traefik-net` network.

## Dockerfile Details

The Dockerfile builds Errbit from source (`main` branch by default). Key points:

- Based on `ruby:4.0.1-slim` with jemalloc for lower memory usage
- Clones from https://github.com/errbit/errbit
- Disables `force_ssl` / `assume_ssl` (TLS termination handled by reverse proxy)
- Custom entrypoint runs `errbit:bootstrap` when `ERRBIT_BOOTSTRAP=true`

To build from a specific branch:
```bash
docker compose build --build-arg ERRBIT_BRANCH=some-branch
```

## Commands

```bash
# View logs
docker compose logs -f errbit

# Restart after config changes
docker compose restart errbit

# Rebuild image (e.g., after Errbit update)
docker compose build --no-cache errbit
docker compose up -d errbit
```
