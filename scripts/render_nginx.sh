#!/usr/bin/env bash
set -euo pipefail

# Render nginx configs from templates using .env
# Run from repo root. Needs sudo to write into /etc/nginx.

if [ ! -f ".env" ]; then
  echo "ERROR: .env not found. Copy .env.example -> .env and fill values."
  exit 1
fi

bash scripts/validate_env.sh

set -a
source .env
set +a

need() { test -n "${!1:-}" || { echo "Missing env: $1"; exit 1; }; }

need PROJECT_NAME
need DOMAIN_BASE
need N8N_SUBDOMAIN
need QDRANT_SUBDOMAIN
need PGADMIN_SUBDOMAIN
need N8N_PORT
need QDRANT_PORT
need PGADMIN_PORT

CLIENT_CODE="${PROJECT_NAME}"

SITES_AVAIL="/etc/nginx/sites-available"
SITES_EN="/etc/nginx/sites-enabled"

render() {
  local in="$1" out="$2"
  envsubst < "$in" > "$out"
}

echo "[1/4] Render templates"
tmpdir="$(mktemp -d)"
render "./nginx/n8n.conf.template"      "$tmpdir/n8n-${CLIENT_CODE}.conf"
render "./nginx/qdrant.conf.template"   "$tmpdir/qdrant-${CLIENT_CODE}.conf"
render "./nginx/pgadmin.conf.template"  "$tmpdir/pgadmin-${CLIENT_CODE}.conf"

echo "[2/4] Install configs"
install -m 0644 "$tmpdir/n8n-${CLIENT_CODE}.conf"     "$SITES_AVAIL/n8n-${CLIENT_CODE}.conf"
install -m 0644 "$tmpdir/qdrant-${CLIENT_CODE}.conf"  "$SITES_AVAIL/qdrant-${CLIENT_CODE}.conf"
install -m 0644 "$tmpdir/pgadmin-${CLIENT_CODE}.conf" "$SITES_AVAIL/pgadmin-${CLIENT_CODE}.conf"

ln -sf "$SITES_AVAIL/n8n-${CLIENT_CODE}.conf"     "$SITES_EN/n8n-${CLIENT_CODE}.conf"
ln -sf "$SITES_AVAIL/qdrant-${CLIENT_CODE}.conf"  "$SITES_EN/qdrant-${CLIENT_CODE}.conf"
ln -sf "$SITES_AVAIL/pgadmin-${CLIENT_CODE}.conf" "$SITES_EN/pgadmin-${CLIENT_CODE}.conf"

echo "[3/4] Validate nginx"
nginx -t

echo "[4/4] Reload nginx"
systemctl reload nginx

echo "DONE (nginx configs rendered & loaded)."
