#!/usr/bin/env bash
set -euo pipefail

# GPSF Stack Update (keeps n8n up to date)
# Steps:
# - git pull
# - docker compose pull
# - docker compose up -d
# - smoke checks localhost

if [ ! -f ".env" ]; then
  echo "ERROR: .env not found."
  exit 1
fi

set -a
source .env
set +a

echo "[1/5] git pull"
git pull --rebase

echo "[2/5] docker compose pull"
docker compose pull

echo "[3/5] docker compose up -d"
docker compose up -d

echo "[4/5] status"
docker compose ps

echo "[5/5] smoke checks"
curl -fsS "http://127.0.0.1:${N8N_PORT:-5678}" >/dev/null && echo "n8n OK (localhost)" || echo "n8n check failed"
curl -fsS "http://127.0.0.1:${QDRANT_PORT:-6333}" >/dev/null && echo "qdrant OK (localhost)" || echo "qdrant check failed"
curl -fsS "http://127.0.0.1:${PGADMIN_PORT:-5050}" >/dev/null && echo "pgadmin OK (localhost)" || echo "pgadmin check failed"

echo "DONE."
