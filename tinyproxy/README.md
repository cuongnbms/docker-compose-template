# Tinyproxy

Lightweight HTTP/HTTPS proxy server using [Tinyproxy](https://github.com/tinyproxy/tinyproxy).

## Quick Start

```bash
docker compose up -d
```

## Configuration

Edit `tinyproxy.conf` to customize the proxy. Key settings:

| Setting | Default | Description |
|---------|---------|-------------|
| `Port` | `8888` | Proxy listen port |
| `Allow` | `0.0.0.0/0` | Allowed client subnets |
| `BasicAuth` | `myuser mypassword` | Basic authentication credentials |
| `Timeout` | `600` | Connection timeout in seconds |
| `MaxClients` | `100` | Maximum concurrent connections |

## Authentication

Basic auth is enabled by default. Update credentials in `tinyproxy.conf`:

```
BasicAuth myuser mypassword
```

To disable auth, remove or comment out the `BasicAuth` line.

## Usage

```bash
# With auth
curl -x http://myuser:mypassword@localhost:8888 http://httpbin.org/ip

# Without auth (if BasicAuth is disabled)
curl -x http://localhost:8888 http://httpbin.org/ip
```

## Restrict Access

For production, replace `Allow 0.0.0.0/0` with specific subnets:

```
Allow 192.168.1.0/24
Allow 10.0.0.0/8
```
