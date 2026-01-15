# GPSF Infra Template (Hostinger LEMP + Docker)

Este repo es el **template** para levantar infra replicable por cliente en VPS Hostinger (LEMP host + Docker Compose).

## Servicios (core)
- n8n
- Postgres
- Redis
- Qdrant

## Ops
- pgAdmin (expuesto por subdominio, pero servido por Nginx)
- Nginx (host) como reverse proxy + SSL

## Dominios
- n8n-<client>.gachetponzellini.com
- qdrant-<client>.gachetponzellini.com
- pgadmin-<client>.gachetponzellini.com

## Quickstart (en VPS)
1) Bootstrap (una vez por VPS): `bash scripts/bootstrap.sh`
2) Deploy: `bash scripts/deploy.sh`
3) Nginx+SSL: `sudo bash scripts/nginx_setup.sh`
4) Import defaults en n8n: healthchecks ON, error bot OFF.

## TL;DR (nuevo VPS)

```bash
git clone <repo>
cd gpsf-infra-template
cp .env.example .env
nano .env

sudo bash scripts/bootstrap.sh      # una sola vez por VPS
bash scripts/deploy.sh
sudo bash scripts/nginx_setup.sh

Ver `docs/PROCESS.md`.
