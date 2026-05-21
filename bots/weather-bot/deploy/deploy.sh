#!/usr/bin/env bash
# Deploy the weather bot on the VPS.
#
# Run by .github/workflows/deploy-weather-bot.yml over SSH *after* the
# bots/weather-bot slice has been rsynced into place. Also runnable by hand:
#   bash deploy/deploy.sh
#
# The VPS holds a flattened copy of bots/weather-bot (not a git checkout),
# so this script does not pull — CI rsyncs the code first.
#
# Prerequisites done once, by hand (see README.md):
#   * the @weather account is registered;
#   * ~/apps/majoin-weather-bot-prod/.env exists (not committed);
#   * the weather-bot systemd unit is installed and enabled;
#   * the deploy user has passwordless `sudo systemctl restart weather-bot`.
#
# Exit codes: 0 success, 1 the service failed to come back up.

set -euo pipefail

SERVICE_NAME="${SERVICE_NAME:-weather-bot}"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "[deploy] $SERVICE_NAME in $PROJECT_ROOT"

# venv + dependencies
[ -d .venv ] || python3 -m venv .venv
.venv/bin/pip install -q --upgrade pip
.venv/bin/pip install -q -r requirements.txt

# restart so the new code is picked up
sudo systemctl restart "$SERVICE_NAME"

# verify it stayed up
sleep 2
if systemctl is-active --quiet "$SERVICE_NAME"; then
  echo "✅ $SERVICE_NAME deployed (${DEPLOY_SHA:-unknown})"
else
  echo "❌ $SERVICE_NAME failed to start"
  journalctl -u "$SERVICE_NAME" -n 40 --no-pager || true
  exit 1
fi
