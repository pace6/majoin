# majoin API Backend

FastAPI service serving both the sticker catalog and the registered user directory for the majoin app.

## Endpoints

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | `/api/stickers/catalog` | none | pack list + featured + categories |
| GET | `/api/stickers/pack/{id}` | none | pack manifest with stickers |
| POST | `/api/stickers/admin/pack` | `X-Admin-Key` | create/update a pack |
| DELETE | `/api/stickers/admin/pack/{id}` | `X-Admin-Key` | remove a pack |
| GET | `/api/users` | none | registered user directory |
| GET | `/api/stickers/health` | none | health probe |

## Deploy (VPS, native — uv, no Docker)

Routine deploys are automated: pushing to `main` with changes under
`services/majoin/**` triggers `.github/workflows/deploy-majoin-api.yml`, which
rsyncs this slice to the VPS and runs `deploy/deploy.sh` (uv sync → alembic
upgrade → restart → health check).

### GitHub repo secrets

| Secret | Value |
|--------|-------|
| `VPS_SSH_KEY` | private SSH key (ed25519) |
| `VPS_HOST` | VPS IP/hostname |
| `VPS_USER` | SSH user — `root` |
| `DEPLOY_DIR` | target dir on the VPS, e.g. `/opt/majoin` |

### One-time VPS bootstrap

Secrets live in `$DEPLOY_DIR/.env` (read by systemd `EnvironmentFile=` and by
`deploy.sh`) — never in the unit file or GitHub. See `deploy/.env.example`.

```bash
# uv — must be on a system path; the systemd unit calls /usr/local/bin/uv
curl -LsSf https://astral.sh/uv/install.sh | sudo sh
sudo ln -sf "$(which uv)" /usr/local/bin/uv

# dir + env
sudo mkdir -p /opt/majoin
sudo cp deploy/.env.example /opt/majoin/.env
sudo nano /opt/majoin/.env          # set DATABASE_URL + STICKER_ADMIN_KEY
sudo chmod 600 /opt/majoin/.env

# systemd unit (edit paths if DEPLOY_DIR is not /opt/majoin)
sudo cp deploy/majoin.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable majoin
```

Then push to `main` (or run the workflow manually) — CI handles the first and
every subsequent deploy.

`uv sync` reads `pyproject.toml`, creates `.venv/`, installs pinned deps.
`uv run` (in the unit file) auto-uses that `.venv`.

Service listens on `127.0.0.1:8410`. Caddy proxies `/api/stickers/*` and `/api/users/*` to it.

### Caddy

Inside the `chat.tokens2.io { ... }` block, **before** `handle /_matrix/*`:

```caddy
handle /api/stickers/* {
    reverse_proxy 127.0.0.1:8410
}
handle /api/users/* {
    reverse_proxy 127.0.0.1:8410
}
```

`sudo systemctl reload caddy`

## Database Migrations (Alembic)

Database schema changes are managed via Alembic.

### Table naming

This service shares the **Synapse** Postgres database. Every table majoin owns
is prefixed `majoin_<module>_<table>` (plural table name) so it never collides
with Synapse's schema — currently:

| Table | Holds |
|-------|-------|
| `majoin_sticker_packs` | sticker pack metadata |
| `majoin_sticker_stickers` | individual stickers per pack |

Synapse's own `users` / `profiles` tables are read as-is by `/api/users` — they
are not majoin tables and are not prefixed.

### Running Migrations Locally

From `services/majoin` directory:

```bash
DATABASE_URL="postgresql://synapse:synapse@localhost:5432/synapse" uv run alembic upgrade head
```

### Creating a New Migration

```bash
uv run alembic revision -m "description of migration"
```
Then edit the newly generated file in `alembic/versions/`.

## Upload a pack

Needs a Matrix access token of any user (a dedicated `@stickerbot` is tidy).
The token uploads images to Synapse media.

```bash
cd /opt/majoin
export MATRIX_HS=https://chat.tokens2.io
export MATRIX_TOKEN=<access token>
export STICKER_API=http://127.0.0.1:8410
export STICKER_ADMIN_KEY=<same key as the service>

# pack folders are the ones shipped in app/assets/stickers/
uv run upload_pack.py majoin_animals /path/to/majoin_animals \
    --name "Cute Animals" --category animals --featured --new

uv run upload_pack.py majoin_food /path/to/majoin_food \
    --name "Yummy Food" --category food --new
```

Get a token quickly:

```bash
curl -XPOST https://chat.tokens2.io/_matrix/client/v3/login \
  -d '{"type":"m.login.password","identifier":{"type":"m.id.user","user":"stickerbot"},"password":"..."}'
# -> use the "access_token" field
```

## Notes

- The app's `majoin_v1` pack stays bundled (offline default) — do **not**
  upload it; it is never served by this API.
- Installed-pack list is stored per user in Matrix `account_data`
  (`app.majoin.stickers`), so it syncs across devices with no DB here.
- Sticker pack and metadata are stored in PostgreSQL (configured via `DATABASE_URL`). Database schemas are managed using Alembic migrations, which must be executed using `alembic upgrade head` before starting the application.
