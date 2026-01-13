#!/usr/bin/env bash
set -euo pipefail

# GPSF Deploy
# Assumes:
# - repo is cloned into /srv/stacks/<client>-prod
# - .env exists

if [ ! -f ".env" ]; then
  echo "ERROR: .env not found. Copy from .env.example and fill values."
  exit 1
fi

echo "[1/4] Validate docker compose config"
docker compose config >/dev/null

echo "[2/4] Pull images"
docker compose pull

echo "[3/4] Up -d"
docker compose up -d

echo "[4/4] Status"
docker compose ps

echo "DONE."
echo "Local checks:"
echo "  curl -sS http://127.0.0.1:${N8N_PORT:-5678} >/dev/null || true"
