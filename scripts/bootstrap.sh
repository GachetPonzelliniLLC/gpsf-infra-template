#!/usr/bin/env bash
set -euo pipefail

# GPSF VPS Bootstrap (Hostinger LEMP compatible)
# - creates deploy user
# - hardens ssh
# - installs docker + compose plugin
# - sets ufw 22/80/443
#
# Run as root (once per VPS).

DEPLOY_USER="${DEPLOY_USER:-deploy}"

echo "[1/6] Creating user: $DEPLOY_USER (if missing)"
if ! id -u "$DEPLOY_USER" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "$DEPLOY_USER"
  usermod -aG sudo "$DEPLOY_USER"
fi

echo "[2/6] Ensure /srv/stacks exists"
mkdir -p /srv/stacks
chown -R "$DEPLOY_USER":"$DEPLOY_USER" /srv/stacks

echo "[3/6] Install Docker (if missing)"
if ! command -v docker >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y ca-certificates curl gnupg lsb-release
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

echo "[4/6] Add $DEPLOY_USER to docker group"
usermod -aG docker "$DEPLOY_USER" || true

echo "[5/6] SSH hardening (no password auth, no root login)"
SSHD="/etc/ssh/sshd_config"
cp "$SSHD" "${SSHD}.bak.$(date +%F_%H%M%S)" || true

# ensure directives exist and are set
sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' "$SSHD" || true
grep -q '^PasswordAuthentication' "$SSHD" || echo 'PasswordAuthentication no' >> "$SSHD"

sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin no/' "$SSHD" || true
grep -q '^PermitRootLogin' "$SSHD" || echo 'PermitRootLogin no' >> "$SSHD"

sed -i 's/^#\?PubkeyAuthentication .*/PubkeyAuthentication yes/' "$SSHD" || true
grep -q '^PubkeyAuthentication' "$SSHD" || echo 'PubkeyAuthentication yes' >> "$SSHD"

systemctl reload ssh || systemctl reload sshd || true

echo "[6/6] UFW firewall (22/80/443)"
if command -v ufw >/dev/null 2>&1; then
  ufw allow 22/tcp
  ufw allow 80/tcp
  ufw allow 443/tcp
  ufw --force enable
fi

echo "DONE. Next:"
echo "1) Add SSH key for $DEPLOY_USER: /home/$DEPLOY_USER/.ssh/authorized_keys"
echo "2) Login as $DEPLOY_USER and deploy the stack."
