#!/usr/bin/env bash
# Generate Synapse homeserver.yaml on first run, then patch for Postgres + open registration (dev).
set -euo pipefail
cd "$(dirname "$0")/.."

export PATH="$HOME/.orbstack/bin:$PATH"

if [ ! -f synapse/data/homeserver.yaml ]; then
  echo "==> Generating Synapse config"
  docker run -it --rm \
    -v "$(pwd)/synapse/data:/data" \
    -e SYNAPSE_SERVER_NAME=localhost \
    -e SYNAPSE_REPORT_STATS=no \
    matrixdotorg/synapse:latest generate

  # Patch: use postgres, enable registration for dev, allow E2EE.
  HS="$(pwd)/synapse/data/homeserver.yaml"

  # Replace sqlite database block with postgres.
  python3 - "$HS" <<'PY'
import sys, re, pathlib
p = pathlib.Path(sys.argv[1])
t = p.read_text()
t = re.sub(
    r"database:\s*\n\s*name:\s*sqlite3\s*\n\s*args:\s*\n\s*database:[^\n]*\n",
    """database:
  name: psycopg2
  args:
    user: synapse
    password: synapse
    database: synapse
    host: postgres
    port: 5432
    cp_min: 5
    cp_max: 10
""",
    t,
)

extra = """
# --- majoin dev overrides ---
enable_registration: true
enable_registration_without_verification: true
registration_shared_secret: "majoin-dev-shared-secret-change-me"
suppress_key_server_warning: true
serve_server_wellknown: true
public_baseurl: "http://localhost:8008/"

# VoIP / TURN — coturn shared-secret auth (must match coturn config).
turn_uris:
  - "turn:host.docker.internal:3478?transport=udp"
  - "turn:host.docker.internal:3478?transport=tcp"
turn_shared_secret: "majoin-dev-turn-secret-change-me"
turn_user_lifetime: 86400000
turn_allow_guests: true
"""
if "majoin dev overrides" not in t:
    t += extra
p.write_text(t)
PY
  echo "==> homeserver.yaml patched for postgres + dev registration"
fi

echo "==> Starting stack"
docker compose up -d postgres synapse
echo "==> Synapse: http://localhost:8008"
echo "==> Register a user:"
echo "    ./scripts/register-user.sh <username> <password>"
