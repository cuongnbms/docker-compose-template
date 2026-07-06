# EMQX MQTT Broker

EMQX 5.x setup with pre-configured authentication and authorization via config files.

## Structure

```
emqx/
├── docker-compose.yml
├── .env.example                   # Template for secrets — copy to .env (gitignored)
├── config/
│   └── emqx.conf                  # Node, cluster, dashboard, authentication & authorization config
├── acl/
│   ├── bootstrap_users.csv.example  # Template — copy to bootstrap_users.csv (gitignored)
│   └── acl.conf                   # Authorization rules
└── host-tuning/
    └── 99-emqx.conf               # Linux kernel (sysctl) tuning for the production host
```

## Source of Truth

> **Config files are the source of truth.** Do not edit authentication, authorization, or other settings from the dashboard — changes made there are saved to the internal `cluster.hocon` in the data volume but will be overridden by `emqx.conf` on every restart and lost on `docker compose down -v`.
>
> Always make changes in the config files and restart the container.

EMQX config precedence (lowest → highest):

```
base.hocon  <  cluster.hocon (dashboard)  <  emqx.conf  <  env vars
```

Our `emqx.conf` sits above `cluster.hocon`, so it always wins on restart.

## Secrets

Secrets are **not** hardcoded in `emqx.conf`. They live in a gitignored `.env` and
are injected as environment variables (which have the highest config precedence).
Two files hold local secrets and are gitignored — commit only their `.example`
templates:

| Real file (gitignored) | Template (committed) | Holds |
|---|---|---|
| `.env` | `.env.example` | node cookie, dashboard password, JWT secret |
| `acl/bootstrap_users.csv` | `acl/bootstrap_users.csv.example` | MQTT user passwords (no env interpolation possible) |

First-time setup:

```bash
cp .env.example .env
cp acl/bootstrap_users.csv.example acl/bootstrap_users.csv
# generate strong values:
#   openssl rand -hex 32      # cookie / JWT secret
#   openssl rand -base64 18   # passwords
# then edit both files
```

How the `.env` values map into EMQX (see `environment:` in `docker-compose.yml`):

| `.env` var | EMQX override key | Config it replaces |
|---|---|---|
| `EMQX_NODE_COOKIE` | `EMQX_NODE__COOKIE` | `node.cookie` |
| `EMQX_DASHBOARD_PASSWORD` | `EMQX_DASHBOARD__DEFAULT_PASSWORD` | `dashboard.default_password` |
| `EMQX_JWT_SECRET` | `EMQX_AUTHENTICATION__2__SECRET` | `secret` of the 2nd authenticator (JWT) |

> The `__2__` index is the JWT authenticator's **position** in the `authentication`
> list in `emqx.conf`. If you reorder the authenticators, update this index.

Guardrails (verified):
- The secret values are removed from `emqx.conf`, so a missing env var is **loud**:
  `docker compose up` aborts on the `${VAR:?}` check, and even bypassing that, EMQX
  refuses to boot (`required_field: authentication.2.secret`) rather than starting
  with a blank, forgeable JWT secret.

> **These do not rotate live credentials.** `dashboard.default_password` and the
> bootstrap CSV are applied **only on first boot with an empty data volume**. On an
> already-running deployment they are ignored — the existing values persist in the
> `emqx-data` volume. To reset from scratch: `docker compose down -v && up -d`
> (destroys all users, sessions, and retained messages).

> **Old secrets remain in git history.** This setup ensures new strong secrets never
> enter git; it does not scrub previously committed placeholders. Since they're all
> being replaced, the old values are dead and safe to abandon.

## Ports

| Port  | Description       |
|-------|-------------------|
| 1883  | MQTT              |
| 8083  | MQTT over WebSocket (add to ports if needed for web clients) |
| 18083 | Dashboard UI      |

## Host Tuning (Production)

EMQX is connection-heavy. The `ulimits.nofile` set in `docker-compose.yml` only
raises limits *inside* the container — it is still capped by the host kernel. On a
Linux production host, apply the sysctl tuning before going live:

```bash
sudo cp host-tuning/99-emqx.conf /etc/sysctl.d/
sudo sysctl --system
```

Verify it took effect:

```bash
sysctl fs.nr_open net.core.somaxconn net.netfilter.nf_conntrack_max
docker exec emqx sh -c 'ulimit -n'   # must print 1048576
```

Key points (see comments in `host-tuning/99-emqx.conf`):

- **`fs.file-max` / `fs.nr_open`** — required, else the container's `nofile` is ignored.
- **`net.netfilter.nf_conntrack_max`** — Docker publishes ports via NAT, so every
  client goes through the conntrack table. A full table silently drops connections
  (`nf_conntrack: table full` in `dmesg`). For >50k–100k connections, consider
  `network_mode: host` to skip NAT entirely.
- **backlog / TCP buffers / port range** — sustain high concurrent connection counts.
- **`vm.swappiness` / `vm.overcommit_memory`** — keep the Erlang VM off swap for
  stable latency.

> These are Linux settings. On a macOS/Docker Desktop dev machine they don't apply
> (Docker runs inside a VM) — only tune the actual Linux production host.

## Start

```bash
cp .env.example .env                                    # first time only: fill in secrets
cp acl/bootstrap_users.csv.example acl/bootstrap_users.csv
docker compose up -d
```

Dashboard: `http://localhost:18083` — login: `admin` / `<EMQX_DASHBOARD_PASSWORD from .env>`

> First start only: bootstrap users from `acl/bootstrap_users.csv` are loaded into the built-in database. Subsequent restarts skip users that already exist (you'll see warnings in logs — this is normal).

## Managing Users

Edit `acl/bootstrap_users.csv`, then recreate the volume to reload:

```
user_id,password,is_superuser
publisher,change-me-strong-password,true   # superuser — full access to all topics
alice,alice-password,false                 # regular user — subject to ACL rules
```

- `is_superuser: true` — bypasses ACL, can publish/subscribe to any topic (use for backend services)
- `is_superuser: false` — subject to `acl/acl.conf` rules

> Users are loaded from the bootstrap file only on first start (empty database). To reload, run `docker compose down -v && docker compose up -d`.

## Authorization Rules

Edit `acl/acl.conf` and restart (`docker compose restart`) to apply. Rules are evaluated top to bottom — first match wins.

Current rules:

```erlang
{allow, {username, "publisher"}, all, ["#"]}.          % publisher: full access
{allow, all, publish,   ["users/${username}/#"]}.       % any user: publish to own topic
{allow, all, subscribe, ["users/${username}/#"]}.       % any user: subscribe to own topic
{allow, all, subscribe, ["public/#"]}.                  % any user: subscribe to public topics
{deny, all}.                                            % deny everything else
```

## Authentication

Two authenticators are configured (tried in order):

1. **Built-in database** — username/password from `bootstrap_users.csv`
2. **JWT (HMAC)** — clients connect with a signed JWT as password; the `sub` claim must match the MQTT username

JWT connection example:
```js
mqtt.connect('mqtt://localhost:1883', {
  username: 'user-123',
  password: '<jwt-signed-with-secret>'  // sub claim must equal 'user-123'
})
```

Update `secret` in `emqx.conf` to match your backend signing key.

## Sending Messages from Backend

### Via MQTT client (Node.js)

```js
import mqtt from 'mqtt'

const client = mqtt.connect('mqtt://localhost:1883', {
  clientId: 'publisher',
  username: 'publisher',
  password: '<publisher password from acl/bootstrap_users.csv>'
})

client.publish('users/123/notifications', JSON.stringify({
  type: 'alert',
  message: 'Hello user!'
}))
```

### Via HTTP API (no persistent connection)

```bash
curl -X POST http://localhost:18083/api/v5/publish \
  -H "Content-Type: application/json" \
  -u "admin:<EMQX_DASHBOARD_PASSWORD from .env>" \
  -d '{
    "topic": "users/123/notifications",
    "payload": "{\"type\": \"alert\", \"message\": \"Hello user!\"}",
    "qos": 1,
    "retain": false
  }'
```

## Topic Convention

```
users/{user_id}/#        # per-user topics (publish & subscribe)
public/#                 # read-only broadcast topics (subscribe only)
```

## Client Side (Web/Mobile)

Web clients connect via WebSocket on port `8083`. Expose it by adding to `docker-compose.yml`:

```yaml
ports:
  - "8083:8083"
```

```js
const client = mqtt.connect('ws://your-server:8083/mqtt', {
  username: 'alice',
  password: 'alice-password'
})

client.subscribe('users/alice/notifications')
client.on('message', (topic, payload) => {
  console.log(JSON.parse(payload.toString()))
})
```
