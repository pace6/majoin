# weather-bot

A Majoin demo bot. When a user registers, it requests friendship (a direct
chat) and reports the weather — once on greeting, then every morning — as a
**Majoin Flex message** (`app.majoin.flex`).

## How it works

```
user registers
      │
      ▼
Synapse  ──(on_user_registration)──►  majoin_register_hook module
                                            │  POST /hooks/new-user {user_id}
                                            ▼
                                      weather-bot
                                       │  create DM + invite user
                                       │  send greeting + weather Flex
                                       ▼
                              every 07:00 (Asia/Bangkok)
                              broadcast forecast Flex to all its chats
```

- Weather: [open-meteo.com](https://open-meteo.com) — free, no API key. Fixed
  to Bangkok (`weather.py` → `CITY` / `LAT` / `LON`).
- The bot creates its own **unencrypted** DM rooms, so it needs no olm/e2e.
- The user sees a chat invite from the bot — accepting it makes the bot a
  friend in the chat list.

## Setup

### 1. Register the bot account

```sh
infra/scripts/register-user.sh weather <password>
```

### 2. Configure

```sh
cd bots/weather-bot
cp .env.example .env      # edit BOT_PASSWORD, HOOK_TOKEN, homeserver
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

### 3. Run

```sh
.venv/bin/python bot.py
```

### 4. Install the Synapse register hook

Copy [`infra/synapse/modules/majoin_register_hook.py`](../../infra/synapse/modules/majoin_register_hook.py)
onto the homeserver where Synapse can import it, then add to `homeserver.yaml`:

```yaml
modules:
  - module: majoin_register_hook.RegisterHook
    config:
      webhook_url: "http://127.0.0.1:8470/hooks/new-user"
      token: "change-me-too"   # must match the bot's HOOK_TOKEN
```

Restart Synapse. New registrations now reach the bot.

## Production deploy

The VPS holds a flattened copy of this directory at `~/apps/majoin-weather-bot-prod`.

### One-time setup (by hand)

1. Register the `@weather` account (above).
2. Create `~/apps/majoin-weather-bot-prod/.env` — never committed, not rsynced.
3. Install the systemd unit:
   ```sh
   # edit User= in the unit first
   sudo cp infra/systemd/majoin-weather-bot.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable --now majoin-weather-bot
   ```
4. Allow the deploy user to restart it without a password — in `sudoers`:
   ```
   <deploy-user> ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart majoin-weather-bot
   ```
5. Install the Synapse register hook (above) — not part of CD.

### Continuous deploy

[`.github/workflows/deploy-weather-bot.yml`](../../.github/workflows/deploy-weather-bot.yml)
runs on every push to `main` that touches `bots/weather-bot/**`: it rsyncs the
slice to `~/apps/majoin-weather-bot-prod` and runs [`deploy/deploy.sh`](deploy/deploy.sh),
which reinstalls dependencies and restarts the service. Uses the existing
`VPS_SSH_KEY` / `VPS_HOST` / `VPS_USER` repo secrets.

## Testing without the Synapse hook

Trigger a greeting manually:

```sh
curl -X POST http://127.0.0.1:8470/hooks/new-user \
  -H "Authorization: Bearer $HOOK_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"user_id":"@alice:chat.tokens2.io"}'
```

## Environment

| Var | Meaning |
|-----|---------|
| `MATRIX_HOMESERVER` | Homeserver base URL |
| `BOT_USER_ID` | The bot's MXID |
| `BOT_PASSWORD` | The bot's password |
| `HOOK_TOKEN` | Shared secret with the Synapse module (Bearer auth) |
| `HOOK_PORT` | Webhook port (default `8470`) |
| `MORNING_HOUR` | Broadcast hour, Asia/Bangkok 0-23 (default `7`) |
