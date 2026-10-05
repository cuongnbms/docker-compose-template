# GlitchTip

Self-hosted GlitchTip 6 behind Traefik, based on the official
[compose.sample.yml](https://glitchtip.com/assets/compose.sample.yml).

- `web` / `worker`: GlitchTip (see the two layouts below)
- `postgres`: PostgreSQL 18 on a private `internal` network (not exposed, not on `traefik-net`)
- `valkey`: cache / task queue, on `traefik-net`, password protected

Two compose files, same `.env` and config:

| File | Layout | When |
|---|---|---|
| `docker-compose.yml` | `web` in `all_in_one` mode (web + worker + migrations in one container) | Small / medium instance, least RAM |
| `docker-compose.split.yml` | `migrate` (one-shot) → `web` (HTTP only) + `worker` (background tasks + scheduler) | Higher load, scale / restart web and worker separately |

With the split file, add `-f docker-compose.split.yml` to every `docker compose` command.
Keep a single `worker` replica (it also runs the scheduler); scale it with `VTASKS_CONCURRENCY` instead.

# Setup

1. Create the secrets file and fill it (passwords hex only, they are embedded in `DATABASE_URL` / `VALKEY_URL`):
```sh
cp .env.example .env
openssl rand -hex 24   # POSTGRES_PASSWORD
openssl rand -hex 24   # VALKEY_PASSWORD
openssl rand -hex 32   # SECRET_KEY
```
`docker compose` refuses to start if any of these is missing.

2. Edit `docker-compose.yml`:
   - `GLITCHTIP_DOMAIN` and the Traefik label `traefik.http.routers.glitchtip.rule`: your domain
   - `EMAIL_URL` / `DEFAULT_FROM_EMAIL`: your SMTP, e.g. `smtp://email:password@smtp_url:port`
     (`consolemail://` sends no email at all)

3. Tune `conf/postgresql.conf` for the VM's RAM (defaults target a 4GB VM shared with GlitchTip).

4. Make sure the external `traefik-net` network exists, then start:
```sh
mkdir -p /data/glitchtip/postgres
docker compose up -d
```
Migrations run automatically on startup.

# Setup without email server
- Set `ENABLE_ADMIN: "True"` and restart, then create a superuser in the web container:
```sh
docker compose exec web ./manage.py createsuperuser
```

- Add user via admin web (`/admin/`)
Admin > User > Add user

- Add user to organization
Admin > Organization user > Add organization user

# Upgrade
```sh
docker compose pull
docker compose up -d
```
- GlitchTip major versions (e.g. `glitchtip:6` → `7`): check https://glitchtip.com/blog/ first.
- PostgreSQL major versions (e.g. 18 → 19): the data directory is not compatible, dump and restore
  (`pg_dumpall`) instead of only bumping the image tag.

# Note
- `ENABLE_USER_REGISTRATION: "False"`: user self-signup is disabled after the first user is registered.
- `POSTGRES_*` values are only applied on first boot with an empty `/data/glitchtip/postgres`.
- Changing `SECRET_KEY` logs out every user.
