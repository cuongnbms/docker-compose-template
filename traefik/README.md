# Traefik (production-ready)

Traefik v3.6 reverse proxy with automatic TLS (Let's Encrypt), global HTTP→HTTPS
redirect, TLS hardening, security headers, access logging and healthcheck.

## Architecture
- Shared external network `traefik-net` — every service that needs to be exposed must join it.
- TLS options enforce TLS 1.2+ and a modern cipher suite — see `traefik-conf/config/traefik.toml`.
- ACME storage at `traefik-conf/acme.json` (gitignored, keep permission `600`).

## Getting started
```sh
# Create the shared network (once)
docker network create traefik-net

docker compose up -d
# To load new config/command changes, recreate (not just restart):
docker compose up -d --force-recreate
```

## Exposing a service through Traefik
On the service's compose file, join `traefik-net` and add labels:
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.<name>.rule=Host(`app.example.com`)"
  - "traefik.http.routers.<name>.entrypoints=https"
  - "traefik.http.routers.<name>.tls.certresolver=ssl"
  # Attach the shared security headers (HSTS, nosniff, frameDeny, ...)
  - "traefik.http.routers.<name>.middlewares=security-headers@docker"
```

## Basic auth
```sh
sudo apt install apache2-utils
htpasswd -n admin
# Eg: admin:$apr1$tPcm4PWb$mUjlTkdl0xTv0pE9XPcXe0
# Double every `$` before putting it into docker compose:
# admin:$$apr1$$tPcm4PWb$$mUjlTkdl0xTv0pE9XPcXe0
```
Attach the auth middleware to a service (chain multiple middlewares with commas):
```
- "traefik.http.routers.<name>.middlewares=security-headers@docker,dev-auth@docker"
```

## Production hardening (enabled)
| Item | Configuration |
|------|---------------|
| TLS 1.2+ & cipher suites | `traefik-conf/config/traefik.toml` → `[tls.options.default]` |
| Security headers (HSTS 1y + preload, nosniff, frameDeny, XSS, referrer-policy) | `security-headers` middleware |
| Healthcheck (`--ping`) | auto-restart when the container hangs |
| Access log (JSON, slow requests > 500ms **or** 4xx/5xx errors) | `traefik_logs` volume → `/logs/access.log` |
| HTTP → HTTPS redirect (permanent) | `redirect-to-https` middleware |
| Prometheus `/metrics` on internal entrypoint | `metrics` entrypoint, published to `127.0.0.1:8082` only |
| Log rotation | json-file, max 10M x 3 |

> ⚠️ **HSTS preload** forces browsers to use HTTPS for a year across the domain and all
> subdomains. Keep it only if every subdomain is served over HTTPS.

## Dashboard (optional)
Uncomment the `# Traefik dashboard` block in `docker-compose.yml` and set
`--api.dashboard=true`. Keep the `dev-auth` + TLS setup as shown.

## Further hardening (not enabled)
- **docker-socket-proxy**: the socket is currently mounted directly (`/var/run/docker.sock`, ro) —
  consider putting a proxy (tecnativa/docker-socket-proxy) in front to reduce attack surface.
- **Resource limits**: uncomment `cpus` / `mem_limit` in `x-default`.
- **Externalize basic-auth credentials** to a `usersfile` instead of hardcoding them in compose.

## Scraping metrics
Prometheus metrics are served on the internal `metrics` entrypoint and published only to
`127.0.0.1:8082`, so they are not reachable from outside the host:
```sh
curl http://127.0.0.1:8082/metrics
```
To scrape from a Prometheus running in another container, put it on `traefik-net` and
target `traefik:8082` instead of publishing the port (or keep the localhost binding and
scrape via a host-network exporter).
