# majoin — VPS deploy (native, no Docker)

End-to-end guide to run the majoin backend on a single Ubuntu/Debian VPS with
**native packages + systemd** — no Docker. Covers Synapse, Postgres, coturn,
sygnal, LiveKit, the sticker API, and Caddy.

The Docker `infra/docker-compose.yml` is for local dev only. Production is
native, as described here.

---

## 0. Overview

| Component | Role | Listens on |
|-----------|------|-----------|
| Postgres | Synapse database | 127.0.0.1:5432 |
| Synapse | Matrix homeserver | 127.0.0.1:8008 |
| coturn | TURN/STUN for 1:1 calls | 3478 / 5349 (public) |
| sygnal | Push gateway (FCM/APNs) | 127.0.0.1:5000 |
| LiveKit | SFU for group calls | 7880 + UDP 50000-50200 |
| lk-jwt-service | Matrix OpenID → LiveKit JWT | 127.0.0.1:8080 |
| majoin API | Stickers & User Directory API | 127.0.0.1:8410 |
| Caddy | TLS reverse proxy | 80 / 443 (public) |

Public hostnames (adjust to your domain):

- `chat.tokens2.io` — Synapse + majoin API
- `livekit.tokens2.io` — LiveKit SFU + JWT service

### DNS

| Record | Type | Value |
|--------|------|-------|
| `chat.tokens2.io` | A | VPS IP |
| `livekit.tokens2.io` | A | VPS IP |

If using Cloudflare: keep `chat` proxied (orange). Set `livekit` to **DNS-only
(grey)** — the LiveKit WebSocket and media do not play well behind the CF proxy.

### Firewall (ufw)

```bash
sudo ufw allow 22/tcp
sudo ufw allow 80,443/tcp
sudo ufw allow 3478,5349/tcp
sudo ufw allow 3478,5349/udp
sudo ufw allow 49152:49252/udp        # coturn relay range
sudo ufw allow 7881/tcp               # LiveKit RTC TCP
sudo ufw allow 50000:50200/udp        # LiveKit RTC UDP
sudo ufw enable
```

---

## 1. Base packages

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl gnupg apt-transport-https \
  python3 python3-venv python3-pip git ufw
```

---

## 2. Postgres

```bash
sudo apt install -y postgresql
sudo -u postgres psql <<'SQL'
CREATE USER synapse WITH PASSWORD 'CHANGE_ME_DB_PASSWORD';
CREATE DATABASE synapse
  ENCODING 'UTF8' LC_COLLATE 'C' LC_CTYPE 'C'
  TEMPLATE template0 OWNER synapse;
SQL
```

---

## 3. Synapse

Install from the matrix.org apt repo:

```bash
sudo apt install -y lsb-release wget
wget -qO /usr/share/keyrings/matrix-org-archive-keyring.gpg \
  https://packages.matrix.org/debian/matrix-org-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/matrix-org-archive-keyring.gpg] \
https://packages.matrix.org/debian/ $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/matrix-org.list
sudo apt update
sudo apt install -y matrix-synapse-py3
```

When prompted for the server name, enter **`chat.tokens2.io`**.

### homeserver.yaml

Edit `/etc/matrix-synapse/homeserver.yaml`:

```yaml
server_name: "chat.tokens2.io"
public_baseurl: "https://chat.tokens2.io/"

# Postgres (replace the generated sqlite block).
database:
  name: psycopg2
  args:
    user: synapse
    password: "CHANGE_ME_DB_PASSWORD"
    database: synapse
    host: 127.0.0.1
    port: 5432
    cp_min: 5
    cp_max: 10

# Registration. Tighten for production as you see fit.
enable_registration: true
enable_registration_without_verification: true
registration_shared_secret: "CHANGE_ME_REG_SECRET"

# TURN — must match coturn static-auth-secret (section 4).
turn_uris:
  - "turn:chat.tokens2.io?transport=udp"
  - "turn:chat.tokens2.io?transport=tcp"
turn_shared_secret: "CHANGE_ME_TURN_SECRET"
turn_user_lifetime: 86400000
turn_allow_guests: true

# Group calls (MatrixRTC / LiveKit).
experimental_features:
  msc3266_enabled: true        # room summary
  msc4222_enabled: true        # sync state-after

# User Directory Search (Allows searching all registered users in Majoin)
user_directory:
  enabled: true
  search_all_users: true
  prefer_local_users: true

# Media.
max_upload_size: 50M
```

Then:

```bash
sudo systemctl enable --now matrix-synapse
sudo systemctl status matrix-synapse
```

### Create users

```bash
sudo register_new_matrix_user -c /etc/matrix-synapse/homeserver.yaml \
  https://chat.tokens2.io
# add -a for an admin account
```

---

## 4. coturn

```bash
sudo apt install -y coturn
```

Enable the service: set `TURNSERVER_ENABLED=1` in `/etc/default/coturn`.

Edit `/etc/turnserver.conf` (see `infra/coturn/turnserver.conf` for reference):

```conf
listening-port=3478
tls-listening-port=5349
min-port=49152
max-port=49252

use-auth-secret
static-auth-secret=CHANGE_ME_TURN_SECRET     # = Synapse turn_shared_secret

realm=chat.tokens2.io
no-tcp-relay
no-multicast-peers
no-tlsv1
no-tlsv1_1
syslog
```

```bash
sudo systemctl enable --now coturn
```

---

## 5. sygnal (push gateway)

```bash
sudo useradd --system --home /opt/sygnal --shell /usr/sbin/nologin sygnal || true
sudo mkdir -p /opt/sygnal/keys
sudo python3 -m venv /opt/sygnal/venv
sudo /opt/sygnal/venv/bin/pip install matrix-sygnal
sudo cp infra/sygnal/sygnal.yaml /opt/sygnal/sygnal.yaml
sudo chown -R sygnal:sygnal /opt/sygnal
```

Edit `/opt/sygnal/sygnal.yaml` — see `docs/push-setup.md`:

- `app.majoin.android` → `api_key`: path to the FCM v1 service account JSON
- `app.majoin.ios` → `certfile`: `/opt/sygnal/keys/apns.p12`

Create `/etc/systemd/system/majoin-sygnal.service`:

```ini
[Unit]
Description=majoin sygnal push gateway
After=network.target

[Service]
Type=simple
User=sygnal
WorkingDirectory=/opt/sygnal
Environment=SYGNAL_CONF=/opt/sygnal/sygnal.yaml
ExecStart=/opt/sygnal/venv/bin/python -m sygnal
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now majoin-sygnal
```

---

## 6. LiveKit + lk-jwt-service (group calls)

### LiveKit SFU

```bash
curl -sSL https://get.livekit.io | sudo bash      # installs /usr/local/bin/livekit-server
sudo mkdir -p /opt/livekit
livekit-server generate-keys                       # note the API key + secret
sudo cp infra/livekit/livekit.yaml /opt/livekit/livekit.yaml
```

Edit `/opt/livekit/livekit.yaml` — put the generated key/secret under `keys:`.

`/etc/systemd/system/majoin-livekit.service`:

```ini
[Unit]
Description=majoin LiveKit SFU
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/livekit-server --config /opt/livekit/livekit.yaml
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
```

### lk-jwt-service

```bash
curl -sSL -o /tmp/lk-jwt.tar.gz \
  https://github.com/element-hq/lk-jwt-service/releases/latest/download/lk-jwt-service-linux-amd64.tar.gz
sudo tar -xzf /tmp/lk-jwt.tar.gz -C /usr/local/bin lk-jwt-service
```

`/etc/systemd/system/majoin-lk-jwt.service`:

```ini
[Unit]
Description=majoin LiveKit JWT service
After=network.target

[Service]
Type=simple
Environment=LIVEKIT_URL=wss://livekit.tokens2.io
Environment=LIVEKIT_KEY=CHANGE_ME_LIVEKIT_API_KEY
Environment=LIVEKIT_SECRET=CHANGE_ME_LIVEKIT_API_SECRET
Environment=LK_JWT_PORT=8080
ExecStart=/usr/local/bin/lk-jwt-service
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now majoin-livekit majoin-lk-jwt
```

`LIVEKIT_KEY` / `LIVEKIT_SECRET` must match `/opt/livekit/livekit.yaml`.

---

## 7. majoin API

```bash
curl -LsSf https://astral.sh/uv/install.sh | sudo sh   # installs uv
sudo mkdir -p /opt/majoin
sudo cp -r services/majoin/{main.py,db.py,upload_pack.py,pyproject.toml,alembic,alembic.ini} \
  /opt/majoin/
sudo chown -R www-data:www-data /opt/majoin
cd /opt/majoin

# create .venv + install deps (run as the service user so it owns the venv)
sudo -u www-data uv sync

# Run database migrations
sudo -u www-data DATABASE_URL="postgresql://synapse:CHANGE_ME_DB_PASSWORD@127.0.0.1:5432/synapse" uv run alembic upgrade head

sudo cp services/majoin/deploy/majoin.service \
  /etc/systemd/system/
sudo nano /etc/systemd/system/majoin.service    # set STICKER_ADMIN_KEY and DATABASE_URL
sudo systemctl daemon-reload
sudo systemctl enable --now majoin
```

See `services/majoin/README.md` for pack uploads.

---

## 8. Caddy (TLS reverse proxy)

```bash
sudo apt install -y debian-keyring debian-archive-keyring
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
  | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
  | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update && sudo apt install -y caddy
```

Use `infra/caddy/Caddyfile` as the basis for `/etc/caddy/Caddyfile`. It already
defines `chat.tokens2.io` (Synapse + majoin API + well-known) and
`livekit.tokens2.io` (SFU + JWT service). If not behind Cloudflare origin
certs, drop the `tls` lines and let Caddy obtain Let's Encrypt certs.

```bash
sudo systemctl reload caddy
```

---

## 9. Verify

```bash
# Synapse
curl https://chat.tokens2.io/_matrix/client/versions
curl https://chat.tokens2.io/.well-known/matrix/client

# Push gateway
curl http://127.0.0.1:5000/_matrix/push/v1/notify -X POST -d '{}'

# LiveKit
curl https://livekit.tokens2.io/healthz          # -> OK

# majoin API
curl https://chat.tokens2.io/api/stickers/health
curl https://chat.tokens2.io/api/users

# Service status
sudo systemctl status matrix-synapse coturn majoin-sygnal \
  majoin-livekit majoin-lk-jwt majoin caddy
```

Then point the client at `https://chat.tokens2.io` (already the default in
`client/lib/core/config.dart`) and log in.

---

## 10. Secrets checklist

Replace every `CHANGE_ME_*` placeholder, and keep them consistent across files:

| Secret | Used in |
|--------|---------|
| DB password | Postgres role + `homeserver.yaml` + `majoin.service` (`DATABASE_URL`) |
| `registration_shared_secret` | `homeserver.yaml` |
| TURN secret | `homeserver.yaml` `turn_shared_secret` + `turnserver.conf` |
| LiveKit API key/secret | `livekit.yaml` + `majoin-lk-jwt.service` |
| `STICKER_ADMIN_KEY` | `majoin.service` |
| FCM service account / APNs cert | `sygnal.yaml` (see `docs/push-setup.md`) |

Never commit real secrets. The repo ships placeholders only.
