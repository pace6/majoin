# Group calls — LiveKit SFU setup

majoin group calls use **MatrixRTC** (call membership over Matrix state) with a
**LiveKit SFU** routing the media. Two new infra services:

- `livekit` — the SFU. Forwards media; never sees plaintext (frames are E2EE'd
  by the clients).
- `lk-jwt-service` — exchanges a Matrix OpenID token for a short-lived LiveKit
  JWT. The client calls it at `/sfu/get`.

1:1 calls are unchanged — they stay peer-to-peer over WebRTC + coturn.

## 1. Generate the LiveKit API key pair

```bash
docker run --rm livekit/livekit-server generate-keys
```

Put the key/secret in **two** places — they must match:

- `infra/livekit/livekit.yaml` → `keys:`
- `infra/docker-compose.yml` → `lk-jwt-service` env `LIVEKIT_KEY` / `LIVEKIT_SECRET`

## 2. DNS + firewall

- `livekit.tokens2.io` → the VPS (Cloudflare, proxied or grey-cloud for WS).
- Open UDP `50000-50200` and TCP `7881` on the host firewall for RTC media.

## 3. Caddy

`infra/caddy/Caddyfile` already routes `livekit.tokens2.io`:

- `/sfu/get` → `lk-jwt-service` (:8080)
- everything else → LiveKit signalling WebSocket (:7880)

## 4. Bring it up

```bash
cd infra
docker compose up -d livekit lk-jwt-service
```

Check: `curl https://livekit.tokens2.io/healthz` → `OK`.

## 5. Client

`AppConfig.livekitJwtServiceUrl` (`client/lib/core/config.dart`) must point at
`https://livekit.tokens2.io`. The client:

1. `fetchOrCreateGroupCall` with a `LiveKitBackend` → publishes its
   `m.call.member` state.
2. POSTs the Matrix OpenID token to `/sfu/get` → receives `{url, jwt}`.
3. Connects `livekit_client` to that URL, publishes camera/mic.
4. Feeds the MatrixRTC-distributed E2EE keys into LiveKit's frame cryptor.

> **Status:** infra + signalling are wired. The `livekit_client` media layer
> must be developed and tested against this running server — there is no way
> to verify the token exchange or media path without it deployed.
