# majoin Sticker Store API

FastAPI service. Serves the sticker catalog to the app; admin endpoint
registers packs. Sticker images live in Synapse media (`mxc://`).

## Endpoints

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | `/api/stickers/catalog` | none | pack list + featured + categories |
| GET | `/api/stickers/pack/{id}` | none | pack manifest with stickers |
| POST | `/api/stickers/admin/pack` | `X-Admin-Key` | create/update a pack |
| DELETE | `/api/stickers/admin/pack/{id}` | `X-Admin-Key` | remove a pack |
| GET | `/api/stickers/health` | none | health probe |

## Deploy (VPS, native — uv, no Docker)

Install [uv](https://docs.astral.sh/uv/) once:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
# uv lands in ~/.local/bin — symlink to a system path for systemd:
sudo ln -sf "$HOME/.local/bin/uv" /usr/local/bin/uv
```

Deploy the service:

```bash
sudo mkdir -p /opt/majoin-stickers
sudo cp main.py db.py upload_pack.py pyproject.toml /opt/majoin-stickers/
cd /opt/majoin-stickers
sudo chown -R www-data:www-data /opt/majoin-stickers

# create .venv + install deps (run as the service user so it owns the venv)
sudo -u www-data uv sync

# systemd
sudo cp majoin-stickers.service /etc/systemd/system/
sudo nano /etc/systemd/system/majoin-stickers.service   # set STICKER_ADMIN_KEY
sudo systemctl daemon-reload
sudo systemctl enable --now majoin-stickers
sudo systemctl status majoin-stickers
```

`uv sync` reads `pyproject.toml`, creates `.venv/`, installs pinned deps.
`uv run` (in the unit file) auto-uses that `.venv`.

Service listens on `127.0.0.1:8410`. Caddy proxies `/api/stickers/*` to it.

### Caddy

Inside the `chat.tokens2.io { ... }` block, **before** `handle /_matrix/*`:

```caddy
handle /api/stickers/* {
    reverse_proxy 127.0.0.1:8410
}
```

`sudo systemctl reload caddy`

## Upload a pack

Needs a Matrix access token of any user (a dedicated `@stickerbot` is tidy).
The token uploads images to Synapse media.

```bash
cd /opt/majoin-stickers
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
- `stickers.db` (SQLite) is created next to `main.py` on first run.
