# majoin

LINE-style chat over [Matrix](https://matrix.org). Flutter client (Android,
iOS, macOS, Windows, Linux) on a self-hosted Synapse homeserver.

## Repository layout

```
majoin/
├── client/        Flutter app (the end-user chat client)
├── services/      Standalone backend APIs we write
│   └── sticker-api/   FastAPI sticker store (catalog + admin)
├── appservices/   Matrix Application Services (registered AS — bridges, puppeting)
├── bots/          Simple Matrix bots (plain user-account bots)
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
| `services/` | standalone REST APIs, not tied to Matrix protocol | sticker-api |
| `appservices/` | Matrix Application Services — registered, own a user namespace, can masquerade users | LINE↔Matrix bridge, puppeting |
| `bots/` | bots that log in as a normal user and react | welcome-bot, broadcast-bot |
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
- Sticker store: `services/sticker-api` (FastAPI, systemd, port 8410)

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

    %% Nodes
    subgraph Client ["Client Devices"]
        App["majoin Client (Flutter)<br/>(Android, iOS, macOS, Windows, Linux)"]:::client
    end

    subgraph Internet ["Public Entrypoints (TLS Reverse Proxy)"]
        Caddy["Caddy Proxy (chat.tokens2.io & livekit.tokens2.io)<br/>Terminates HTTPS / WSS"]:::proxy
    end

    subgraph AudioVideo ["Real-time Calling Infrastructure"]
        Coturn["coturn TURN/STUN Server<br/>(Ports 3478/5349 & UDP 49152-49252)"]:::services
        LiveKit["LiveKit SFU (Group Calls)<br/>(Ports 7880/7881 & UDP 50000-50200)"]:::services
    end

    subgraph ApplicationStack ["Application Backend Services"]
        Synapse["Synapse Matrix Homeserver<br/>(Python/Twisted, Port 8008)"]:::matrix
        StickerAPI["FastAPI Sticker Store API<br/>(uv / python, Port 8410)"]:::services
        Sygnal["Sygnal Push Gateway<br/>(Python, Port 5000)"]:::services
        LKJWT["lk-jwt-service (LiveKit JWT Service)<br/>(Go, Port 8080)"]:::services
    end

    subgraph DataStorage ["Data Stores"]
        Postgres[(PostgreSQL Database<br/>Port 5432)]:::database
    end

    subgraph ExternalServices ["External APIs / Services"]
        FCM["Firebase Cloud Messaging (FCM)<br/>Google Push Notifications"]:::external
        APNS["Apple Push Notification Service (APNs)"]:::external
    end

    %% Flows
    App ==>|"1. HTTPS / WSS (chat.tokens2.io)"| Caddy
    App ==>|"2. WebRTC Media (1:1 direct / TURN relay)"| Coturn
    App ==>|"3. WebRTC Media (Group Calls)"| LiveKit

    Caddy ==>|"Proxy (/_matrix/* & .well-known/*)"| Synapse
    Caddy ==>|"Proxy (/api/stickers/*)"| StickerAPI
    Caddy ==>|"Proxy (livekit.tokens2.io/)"| LiveKit
    Caddy ==>|"Proxy (livekit.tokens2.io/jwt)"| LKJWT

    Synapse ==>|"DB Queries"| Postgres
    Synapse ==>|"Trigger Push Events"| Sygnal
    Synapse -.->|"TURN Authentication Secret"| Coturn

    StickerAPI ==>|"Sticker Pack Metadata"| Postgres
    StickerAPI -->|"Upload Media Assets (mxc://)"| Synapse

    LKJWT ==>|"Exchange Matrix OpenID for User Verification"| Synapse
    LKJWT -.->|"Issues signed JWT tokens for"| LiveKit

    Sygnal ==>|Push Push Notifications| FCM
    Sygnal ==>|Push Push Notifications| APNS
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

## Component docs

- `services/sticker-api/README.md` — sticker store API deploy + pack upload
- `infra/scripts/` — Synapse bootstrap + user registration
- `docs/push-setup.md` — FCM remote push setup (Firebase + sygnal)
