# EMQX MQTT Broker

EMQX 5.x setup with pre-configured authentication and authorization via config files.

## Structure

```
emqx/
├── docker-compose.yml
├── config/
│   └── emqx.conf              # Node, cluster, dashboard, authentication & authorization config
└── acl/
    ├── bootstrap_users.csv    # Pre-loaded MQTT users (username, password, is_superuser)
    └── acl.conf               # Authorization rules
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

## Ports

| Port  | Description       |
|-------|-------------------|
| 1883  | MQTT              |
| 8083  | MQTT over WebSocket (add to ports if needed for web clients) |
| 18083 | Dashboard UI      |

## Start

```bash
docker compose up -d
```

Dashboard: `http://localhost:18083` — login: `admin` / `dev`

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
  password: 'change-me-strong-password'
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
  -u "admin:dev" \
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
