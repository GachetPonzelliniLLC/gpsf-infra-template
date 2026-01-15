#!/usr/bin/env bash
set -euo pipefail

# GPSF Nginx + SSL setup (nginx on host)
# Run with sudo from repo root:
#   sudo bash scripts/nginx_setup.sh

if [ ! -f ".env" ]; then
  echo "ERROR: .env not found. Copy .env.example -> .env and fill values."
  exit 1
fi

bash scripts/validate_env.sh

set -a
source .env
set +a

need() { test -n "${!1:-}" || { echo "Missing env: $1"; exit 1; }; }

need DOMAIN_BASE
need N8N_SUBDOMAIN
need QDRANT_SUBDOMAIN
need PGADMIN_SUBDOMAIN
need LETSENCRYPT_EMAIL

echo "[1/3] Install certbot if missing"
if ! command -v certbot >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y certbot python3-certbot-nginx
fi

echo "[2/3] Render + install nginx configs"
sudo bash scripts/render_nginx.sh

echo "[3/3] Issue certificates (LetsEncrypt) for subdomains"
DOMAINS=(
  "${N8N_SUBDOMAIN}.${DOMAIN_BASE}"
  "${QDRANT_SUBDOMAIN}.${DOMAIN_BASE}"
  "${PGADMIN_SUBDOMAIN}.${DOMAIN_BASE}"
)

certbot --nginx --non-interactive --agree-tos -m "$LETSENCRYPT_EMAIL" \
  $(printf -- " -d %s" "${DOMAINS[@]}") || true

systemctl reload nginx

echo "DONE. Verify:"
echo "  https://${N8N_SUBDOMAIN}.${DOMAIN_BASE}"
echo "  https://${QDRANT_SUBDOMAIN}.${DOMAIN_BASE}"
echo "  https://${PGADMIN_SUBDOMAIN}.${DOMAIN_BASE}"
