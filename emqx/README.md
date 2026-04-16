# EMQX MQTT Broker

EMQX 5.x setup with pre-configured authentication via config files.

## Structure

```
emqx/
├── docker-compose.yml
├── config/
│   └── emqx.conf              # Authentication & authorization config
└── acl/
    └── bootstrap_users.csv    # Pre-loaded MQTT users
```

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

## Managing Users

Users are stored in the `emqx-data` volume and persist across restarts.

**Create a user (run once after first start):**

```bash
curl -X POST http://localhost:18083/api/v5/authentication/password_based:built_in_database/users \
  -H "Content-Type: application/json" \
  -u "admin:dev" \
  -d '{"user_id": "backend-service", "password": "change-me-strong-password", "is_superuser": true}'
```

- `is_superuser: true` — can publish/subscribe to any topic (use for backend services)
- `is_superuser: false` — subject to ACL rules (use for end clients)

**List users:**
```bash
curl -u "admin:dev" http://localhost:18083/api/v5/authentication/password_based:built_in_database/users
```

**Delete a user:**
```bash
curl -X DELETE -u "admin:dev" \
  http://localhost:18083/api/v5/authentication/password_based:built_in_database/users/backend-service
```

> Users are lost if you run `docker compose down -v`. Re-run the create commands after recreating the volume.

## Sending Messages from Backend

### Via MQTT client (Node.js)

```js
import mqtt from 'mqtt'

const client = mqtt.connect('mqtt://localhost:1883', {
  clientId: 'backend-service',
  username: 'backend-service',
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
users/{user_id}/notifications    # push to specific user
broadcast/all                    # push to all users
```

## Client Side (Web/Mobile)

Web clients connect via WebSocket on port `8083`. Expose it by adding to `docker-compose.yml`:

```yaml
ports:
  - "8083:8083"
```

```js
const client = mqtt.connect('ws://your-server:8083/mqtt', {
  username: 'mobile-client',
  password: 'client-password'
})

client.subscribe('users/123/notifications')
client.on('message', (topic, payload) => {
  console.log(JSON.parse(payload.toString()))
})
```
