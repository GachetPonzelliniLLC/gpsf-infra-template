#!/usr/bin/env bash
set -euo pipefail

# GPSF Nginx + SSL setup for Hostinger LEMP (nginx on host)
# Requires:
# - run from repo root (where .env exists)
# - templates in ./nginx/*.template
# - certbot installed (will install if missing)
#
# Run with sudo:
#   sudo bash scripts/nginx_setup.sh

# 0) Ensure .env exists
if [ ! -f ".env" ]; then
  echo "ERROR: .env not found in current directory."
  echo "Hint: copy .env.example -> .env and fill values."
  exit 1
fi

# 1) Validate env (hard-stop if missing required vars)
bash scripts/validate_env.sh

# 2) Load env into current shell (for envsubst + script vars)
set -a
source .env
set +a

need() { test -n "${!1:-}" || { echo "Missing env: $1"; exit 1; }; }

# Required for this script
need PROJECT_NAME
need DOMAIN_BASE
need N8N_SUBDOMAIN
need QDRANT_SUBDOMAIN
need PGADMIN_SUBDOMAIN
need N8N_PORT
need QDRANT_PORT
need PGADMIN_PORT
need LETSENCRYPT_EMAIL

CLIENT_CODE="${PROJECT_NAME}"

SITES_AVAIL="/etc/nginx/sites-available"
SITES_EN="/etc/nginx/sites-enabled"

render() {
  local in="$1" out="$2"
  envsubst < "$in" > "$out"
}

echo "[1/6] Install certbot if missing"
if ! command -v certbot >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y certbot python3-certbot-nginx
fi

echo "[2/6] Render nginx configs"
tmpdir="$(mktemp -d)"
render "./nginx/n8n.conf.template"      "$tmpdir/n8n-${CLIENT_CODE}.conf"
render "./nginx/qdrant.conf.template"   "$tmpdir/qdrant-${CLIENT_CODE}.conf"
render "./nginx/pgadmin.conf.template"  "$tmpdir/pgadmin-${CLIENT_CODE}.conf"

echo "[3/6] Install configs"
install -m 0644 "$tmpdir/n8n-${CLIENT_CODE}.conf"     "$SITES_AVAIL/n8n-${CLIENT_CODE}.conf"
install -m 0644 "$tmpdir/qdrant-${CLIENT_CODE}.conf"  "$SITES_AVAIL/qdrant-${CLIENT_CODE}.conf"
install -m 0644 "$tmpdir/pgadmin-${CLIENT_CODE}.conf" "$SITES_AVAIL/pgadmin-${CLIENT_CODE}.conf"

ln -sf "$SITES_AVAIL/n8n-${CLIENT_CODE}.conf"     "$SITES_EN/n8n-${CLIENT_CODE}.conf"
ln -sf "$SITES_AVAIL/qdrant-${CLIENT_CODE}.conf"  "$SITES_EN/qdrant-${CLIENT_CODE}.conf"
ln -sf "$SITES_AVAIL/pgadmin-${CLIENT_CODE}.conf" "$SITES_EN/pgadmin-${CLIENT_CODE}.conf"

echo "[4/6] Validate nginx"
nginx -t

echo "[5/6] Reload nginx"
systemctl reload nginx

echo "[6/6] Issue certificates (LetsEncrypt) for subdomains"
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
