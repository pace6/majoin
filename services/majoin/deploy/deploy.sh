#!/usr/bin/env bash
# Deploy the majoin API on the VPS.
#
# Run by .github/workflows/deploy-majoin-api.yml over SSH *after* the
# services/majoin slice has been rsynced into place. Also runnable by hand
# on the box:  bash deploy/deploy.sh
#
# Monorepo note: the VPS holds a flattened copy of services/majoin (not a
# git checkout), so this script does not pull — CI rsyncs the code first.
#
# Config — read from PROJECT_ROOT/.env (see deploy/.env.example):
#   DATABASE_URL               Postgres DSN (required — alembic runs outside systemd)
#   STICKER_ADMIN_KEY          consumed by the service, not this script
#   SLACK_DEPLOY_WEBHOOK_URL   Slack incoming-webhook URL — silent if unset
# The deploy/SSH user owns the code, runs uv, and is the systemd unit's
# User= — no separate service account.
#
# Optional environment:
#   SERVICE_NAME   systemd unit name (default: majoin)
#   HEALTH_URL     endpoint polled after restart (default: chat.tokens2.io health)
#   DEPLOY_SHA     commit SHA, passed by CI — shown in the Slack message
#
# Exit codes: 0 success, 1+ a phase failed (Slack gets ❌ with the phase).

set -euo pipefail

SERVICE_NAME="${SERVICE_NAME:-majoin}"
SLACK_USERNAME="${SLACK_USERNAME:-majoin-deploy}"
HEALTH_URL="${HEALTH_URL:-https://chat.tokens2.io/api/stickers/health}"
START_TS="$(date +%s)"
PHASE="setup"   # mutated by each phase; the ERR trap reports it

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

# Load .env so alembic (run here, outside systemd) sees DATABASE_URL.
# Already-set environment values win. Tolerates an optional `export ` prefix.
if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

if [ -z "${DATABASE_URL:-}" ]; then
  echo "[deploy] DATABASE_URL not set — create $PROJECT_ROOT/.env" >&2
  exit 1
fi

# uv is installed per-user by the bootstrap (curl | sh) — run deploy.sh as
# that user. The systemd unit can't expand $HOME, so it uses the
# /usr/local/bin/uv symlink instead.
UV_BIN="${UV_BIN:-$HOME/.local/bin/uv}"

# ─── Slack helper ────────────────────────────────────────────────────────
post_slack() {
  local emoji="$1" text="$2"
  [ -z "${SLACK_DEPLOY_WEBHOOK_URL:-}" ] && return 0
  local payload
  payload=$(python3 -c '
import json, sys
print(json.dumps({
  "username": sys.argv[1],
  "icon_emoji": sys.argv[2],
  "text": sys.argv[3],
}))' "$SLACK_USERNAME" "$emoji" "$text")
  curl -fsS -X POST -H 'Content-Type: application/json' \
    --data "$payload" "$SLACK_DEPLOY_WEBHOOK_URL" > /dev/null || true
}

on_error() {
  local code=$?
  local elapsed=$(( $(date +%s) - START_TS ))
  post_slack ":x:" "❌ majoin deploy failed at *${PHASE}* (exit ${code}) · ${elapsed}s"
  exit "$code"
}
trap on_error ERR

echo "Deploying majoin in $PROJECT_ROOT..."

# ─── Phases ──────────────────────────────────────────────────────────────
# CI rsyncs as the deploy user, so the tree is already owned correctly —
# uv and alembic run directly as that user. DATABASE_URL was exported from
# .env above, so alembic picks it up.
PHASE="uv sync"
"$UV_BIN" sync --frozen

PHASE="alembic upgrade head"
"$UV_BIN" run alembic upgrade head

# restart (NOT reload) so the DB driver drops its connection pool and the
# new uvicorn process picks up the new schema.
PHASE="systemctl restart ${SERVICE_NAME}"
sudo systemctl restart "$SERVICE_NAME"

# ─── Verify the service is live ─────────────────────────────────────────
PHASE="health check"
LIVE="no"
for _ in {1..10}; do
  if curl -fsS --max-time 3 "$HEALTH_URL" > /dev/null 2>&1; then
    LIVE="yes"
    break
  fi
  sleep 1
done

ELAPSED=$(( $(date +%s) - START_TS ))
SHA="${DEPLOY_SHA:-unknown}"
if [ "$LIVE" = "yes" ]; then
  echo "✅ Deployed ${SHA} (${ELAPSED}s) — health OK"
  post_slack ":white_check_mark:" "✅ majoin deployed \`${SHA}\` · ${ELAPSED}s · health ✓"
else
  echo "⚠️  Deployed ${SHA} but health check failed (${ELAPSED}s)"
  post_slack ":warning:" "⚠️ majoin deployed \`${SHA}\` · ${ELAPSED}s · health ✗"
  exit 1
fi
