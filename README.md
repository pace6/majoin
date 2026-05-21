# Majoin

LINE-style chat over [Matrix](https://matrix.org). Flutter client (Android,
iOS, macOS, Windows, Linux) on a self-hosted Synapse homeserver.

## Repository layout

```
majoin/
├── client/        Flutter app (the end-user chat client)
├── services/      Standalone backend APIs we write
│   └── majoin/        FastAPI app API (stickers, user directory, custom endpoints)
├── appservices/   Matrix Application Services (registered AS — bridges, puppeting)
├── bots/          Simple Matrix bots (plain user-account bots)
│   └── weather-bot/   weather reports + Claude chat (matrix-nio)
├── infra/         Matrix deploy + reverse proxy
│   ├── synapse/       homeserver config + data
│   ├── coturn/        TURN server config
│   ├── sygnal/        push gateway config
│   ├── caddy/         Caddyfile reference
│   ├── systemd/       unit files
│   └── scripts/       bootstrap.sh, register-user.sh
├── tools/         Dev tooling (asset generators)
│   └── sticker-gen/   sticker placeholder PNG generators
└── docs/          Architecture notes, runbooks
```

### What goes where

| Dir | Definition | Examples |
|-----|------------|----------|
| `client/` | end-user application | Flutter app |
| `services/` | standalone REST APIs, not tied to Matrix protocol | majoin (stickers, user API, custom endpoints) |
| `appservices/` | Matrix Application Services — registered, own a user namespace, can masquerade users | LINE↔Matrix bridge, puppeting |
| `bots/` | bots that log in as a normal user and react | weather-bot |
| `infra/` | deploy config for the Matrix stack + reverse proxy | Synapse, coturn, sygnal, Caddy |
| `tools/` | dev-time scripts, never deployed | asset generators |

**bot vs appservice:** a *bot* is one ordinary user account that logs in and
reacts. An *appservice* is registered with Synapse via a registration file,
gets a user-id namespace, and can act on behalf of many users — required for
bridges and puppeting.

## Production setup (current)

- Homeserver: `https://chat.tokens2.io` (Synapse, native install on VPS)
- Reverse proxy: Caddy (`/_matrix/*`, `/api/stickers/*`)
- TURN: coturn (native)
- App API: `services/majoin` (FastAPI — sticker store + user directory, and
  the home for new custom endpoints; systemd, port 8410)
- Weather bot: `bots/weather-bot` (matrix-nio, systemd; demo bot)

### Infrastructure Architecture

![Infrastructure Diagram](docs/infrastructure_diagram.svg)

<details>
<summary>Show Mermaid Source</summary>

```mermaid
graph TB
    %% Styling
    classDef client fill:#3A86FF,stroke:#000,stroke-width:1.5px,color:#fff;
    classDef proxy fill:#8338EC,stroke:#000,stroke-width:1.5px,color:#fff;
    classDef matrix fill:#FF006E,stroke:#000,stroke-width:1.5px,color:#fff;
    classDef services fill:#FFB703,stroke:#000,stroke-width:1.5px,color:#333;
    classDef database fill:#06D6A0,stroke:#000,stroke-width:1.5px,color:#fff;
    classDef external fill:#7D8597,stroke:#000,stroke-dasharray: 5 5,stroke-width:1.5px,color:#fff;
    classDef bot fill:#06C755,stroke:#000,stroke-width:1.5px,color:#fff;
    classDef planned fill:#FFFFFF,stroke:#7D8597,stroke-dasharray: 6 4,stroke-width:1.5px,color:#333;

    %% Nodes
    subgraph Client ["Client Devices"]
        App["Majoin Client (Flutter)<br/>(Android, iOS, macOS, Windows, Linux)"]:::client
    end

    subgraph Internet ["Public Entrypoints (TLS Reverse Proxy)"]
        Caddy["Caddy Proxy (chat.tokens2.io & livekit.tokens2.io)<br/>Terminates HTTPS / WSS"]:::proxy
    end

    subgraph AudioVideo ["Real-time Calling Infrastructure"]
        Coturn["coturn TURN/STUN Server<br/>(Ports 3478/5349 & UDP 49152-49252)"]:::services
        LiveKit["LiveKit SFU (Group Calls)<br/>(Ports 7880/7881 & UDP 50000-50200)"]:::services
    end

    subgraph ApplicationStack ["Application Backend Services"]
        Synapse["Synapse Matrix Homeserver<br/>(Python/Twisted, Port 8008)<br/>+ majoin_register_hook module"]:::matrix
        StickerAPI["Majoin App API (FastAPI)<br/>stickers · user directory · custom<br/>(uv / python, Port 8410)"]:::services
        Sygnal["Sygnal Push Gateway<br/>(Python, Port 5000)"]:::services
        LKJWT["lk-jwt-service (LiveKit JWT Service)<br/>(Go, Port 8080)"]:::services
    end

    subgraph Integrations ["Bots & Application Services"]
        WeatherBot["weather-bot<br/>(matrix-nio, Python, Port 8470)<br/>greets new users, daily forecast, Claude chat"]:::bot
        Bridge["LINE&lt;-&gt;Matrix Bridge<br/>(appservice — TODO / example)"]:::planned
    end

    subgraph DataStorage ["Data Stores"]
        Postgres[(PostgreSQL Database<br/>Port 5432)]:::database
    end

    subgraph ExternalServices ["External APIs / Services"]
        FCM["Firebase Cloud Messaging (FCM)<br/>Google Push Notifications"]:::external
        APNS["Apple Push Notification Service (APNs)"]:::external
        OpenMeteo["open-meteo API<br/>(weather data, no key)"]:::external
        Anthropic["Anthropic API<br/>(Claude Agent SDK)"]:::external
        LineP["LINE Platform<br/>(bridged network)"]:::external
    end

    %% Flows
    App ==>|"1. HTTPS / WSS (chat.tokens2.io)"| Caddy
    App ==>|"2. WebRTC Media (1:1 direct / TURN relay)"| Coturn
    App ==>|"3. WebRTC Media (Group Calls)"| LiveKit

    Caddy ==>|"Proxy (/_matrix/* & .well-known/*)"| Synapse
    Caddy ==>|"Proxy (/api/*)"| StickerAPI
    Caddy ==>|"Proxy (livekit.tokens2.io/)"| LiveKit
    Caddy ==>|"Proxy (livekit.tokens2.io/jwt)"| LKJWT

    Synapse ==>|"DB Queries"| Postgres
    Synapse ==>|"Trigger Push Events"| Sygnal
    Synapse -.->|"TURN Authentication Secret"| Coturn

    StickerAPI ==>|"App data (packs, users)"| Postgres
    StickerAPI -->|"Upload Media Assets (mxc://)"| Synapse
    StickerAPI -.->|"Verify caller token (/account/whoami)"| Synapse

    LKJWT ==>|"Exchange Matrix OpenID for User Verification"| Synapse
    LKJWT -.->|"Issues signed JWT tokens for"| LiveKit

    Sygnal ==>|Push Push Notifications| FCM
    Sygnal ==>|Push Push Notifications| APNS

    %% Bot flows
    WeatherBot ==>|"Matrix client API (login / sync / send)"| Synapse
    Synapse -.->|"register hook: POST /hooks/new-user"| WeatherBot
    WeatherBot ==>|"Forecast"| OpenMeteo
    WeatherBot ==>|"Conversational replies"| Anthropic

    %% Application service (planned)
    Bridge -.->|"Appservice API (registered namespace)"| Synapse
    Bridge -.->|"Bridged messages"| LineP
```
</details>

## Quick start (client dev)

```bash
cd client
flutter pub get
flutter run -d macos        # or any connected device
```

Login screen points at `https://chat.tokens2.io` (hardcoded in
`client/lib/core/config.dart`). Register in-app or via:

```bash
# on the homeserver
sudo register_new_matrix_user -c /etc/matrix-synapse/homeserver.yaml \
    http://localhost:8008
```

## Features

| Area | Status |
|------|--------|
| Login / register (password) | done |
| DM + group rooms | done |
| Text / image / video / audio / file messages | done |
| Stickers + sticker store API | done |
| LINE Flex Message renderer (3 demos) | done |
| Reply / copy / unsend / forward / edit | done |
| Reactions, read receipts, typing indicator | done |
| History pagination, room search | done |
| E2EE: recovery key, cross-signing, key backup, device verification | done |
| 1:1 voice + video call (WebRTC + coturn) | wired, MVP |
| TH / EN localization | done |
| Push — local notifications (all platforms) | done |
| Push — FCM / APNs remote (background/killed) | wired; needs Firebase config |
| Group call (LiveKit) | planned (Phase 2) |
| Weather bot — Flex reports + Claude Agent SDK chat | demo |
| LINE↔Matrix bridge (appservice) | TODO / example |

## Component docs

- `services/majoin/README.md` — app API deploy + sticker pack upload
- `docs/custom-api-auth.md` — protecting custom API endpoints with Matrix tokens
- `bots/weather-bot/README.md` — weather bot setup, register hook, CD
- `infra/scripts/` — Synapse bootstrap + user registration
- `docs/push-setup.md` — FCM remote push setup (Firebase + sygnal)
