#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.orbstack/bin:$PATH"
USER="${1:?usage: register-user.sh <user> <pass> [--admin]}"
PASS="${2:?usage: register-user.sh <user> <pass> [--admin]}"
ADMIN_FLAG="${3:-}"
ADMIN_ARG=""
if [ "$ADMIN_FLAG" = "--admin" ]; then ADMIN_ARG="-a"; fi

cd "$(dirname "$0")/.."
docker compose exec synapse register_new_matrix_user \
  -u "$USER" -p "$PASS" $ADMIN_ARG \
  -c /data/homeserver.yaml \
  http://localhost:8008
