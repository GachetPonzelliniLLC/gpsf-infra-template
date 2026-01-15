#!/usr/bin/env bash
set -e

REQUIRED_VARS=(
  PROJECT_NAME
  DOMAIN_BASE
  POSTGRES_PASSWORD
  N8N_BASIC_AUTH_PASSWORD
)

echo "🔎 Validando .env..."

for VAR in "${REQUIRED_VARS[@]}"; do
  if ! grep -q "^$VAR=" .env || grep -q "^$VAR=$" .env; then
    echo "❌ Variable obligatoria no definida: $VAR"
    exit 1
  fi
done

echo "✅ .env OK"
