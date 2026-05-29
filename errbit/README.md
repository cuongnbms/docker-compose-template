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

### Data Retention

| Variable | Description | Default |
|----------|-------------|---------|
| `ERRBIT_PROBLEM_DESTROY_AFTER_DAYS` | Days to keep errors before `errbit:clear_outdated` purges them. Empty = disabled | `90` |

See [Data Retention](#data-retention-1) below for how to schedule the purge.

### Email Notifications

| Variable | Description | Default |
|----------|-------------|---------|
| `ERRBIT_EMAIL_FROM` | Sender address for notification emails | `errbit@example.com` |
| `ERRBIT_EMAIL_AT_NOTICES` | Send email at these notice counts | `[1,10,100]` |
| `ERRBIT_NOTIFY_AT_NOTICES` | Trigger notifications at these counts | `[0]` |

### OAuth (Optional)

GitHub and Google OAuth can be enabled by setting `GITHUB_AUTHENTICATION=true` or `GOOGLE_AUTHENTICATION=true` and providing the corresponding client ID and secret.

## Data Retention

Errbit does **not** purge old errors automatically. MongoDB grows unbounded unless
you schedule cleanup. Errbit ships a rake task `errbit:clear_outdated` that deletes
problems older than `ERRBIT_PROBLEM_DESTROY_AFTER_DAYS` (set in `.env`, default `90`).

Run it manually to test:

```bash
docker compose exec -T errbit bundle exec rails errbit:clear_outdated
```

To run it daily, add a **host cron job** (`crontab -e` as root). Runs at 03:00 every day:

```cron
0 3 * * * cd /opt/errbit && /usr/bin/docker compose exec -T errbit bundle exec rails errbit:clear_outdated >> /var/log/errbit-cleanup.log 2>&1
```

Notes:
- `-T` is required — disables TTY allocation, otherwise cron fails with `the input device is not a TTY`.
- Use `cd /opt/errbit` (or `docker compose -f /opt/errbit/docker-compose.yml`) so compose finds the project.
- Use an absolute path to `docker` (`which docker`) since cron has a minimal `PATH`.
- The retention period lives in `.env`; only the schedule lives in the host crontab.

> Other useful tasks: `errbit:clear_resolved` (delete resolved errors), `errbit:notices_delete` (batch-delete notices).

## Traefik Integration

The compose file includes Traefik labels. Update the `Host` rule in `docker-compose.yml` to match your domain:

```yaml
- "traefik.http.routers.errbit.rule=Host(`errbit.example.com`)"
```

Requires the external `traefik-net` network.

## Dockerfile Details

The Dockerfile builds Errbit from source, pinned to a release tag (`v0.10.11` by default). Key points:

- Based on `ruby:3.4.9-slim` (matches the pinned tag's `.ruby-version`) with jemalloc for lower memory usage
- Clones from https://github.com/errbit/errbit
- Disables `force_ssl` / `assume_ssl` (TLS termination handled by reverse proxy)
- Custom entrypoint runs `errbit:bootstrap` when `ERRBIT_BOOTSTRAP=true`

To build from a different branch/tag, set `ERRBIT_BRANCH` in `.env` (compose passes it as a build arg):
```bash
# in .env
ERRBIT_BRANCH=v0.10.11
```

> **Important:** if you change `ERRBIT_BRANCH`, check that tag's `.ruby-version` and
> `Gemfile.lock` (`BUNDLED WITH`) and update the `FROM ruby:...-slim` base image and the
> pinned `bundler` version in the Dockerfile to match — otherwise `bundle install` fails.

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
