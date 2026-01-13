# GPSF — Infra cliente replicable (Template v1)

## Qué significa “upgrade”
Hay 2 upgrades distintos:

1) **Upgrade del stack (Docker)**  
Actualizar imágenes (n8n/postgres/redis/qdrant/pgadmin), cambios de `docker-compose.yml`, cambios de Nginx, etc.  
Esto es lo que te importa para “mantener n8n al día”.

2) **Upgrade del sistema (Ubuntu / paquetes)**  
Actualización de OS/kernel/openssh/nginx host, etc.  
Esto va aparte, con snapshot/ventana de mantenimiento.

Este documento define el **proceso completo** para: bootstrap → deploy → DNS/Nginx/SSL → defaults n8n → updates.

---

## Estándar de dominios
- `n8n-<client>.gachetponzellini.com`
- `qdrant-<client>.gachetponzellini.com`
- `pgadmin-<client>.gachetponzellini.com`

`<client>`: abreviación corta en minúsculas (ej: `ayv`, `vinesco`, `damfield`).

---

## Principios operativos
- Exposición **solo por Nginx** (host).  
- Puertos internos mapeados a **127.0.0.1** (no públicos).
- Todo corre en **Docker network** interna.
- Qdrant **expuesto** por subdominio.
- pgAdmin **expuesto** por subdominio.
- n8n expuesto por subdominio.
- En n8n:
  - **Healthchecks**: único workflow activo día 1.
  - **GPSF Error Bot**: configurado pero **desactivado** hasta que haya workflows reales en prod.

---

## Repo y layout (decisión final)
Usamos **1 repo template** en GitHub y en el VPS clonamos **una copia por cliente** en:

`/srv/stacks/<client>-prod/`

Esto NO significa “monorepo con todos los clientes adentro”.  
Significa: el mismo repo template se clona en distintas carpetas (una por cliente) y se parametriza por `.env`.

Ventaja: actualizás el template y podés replicar el mismo update en todos los VPS/clients con el mismo flujo.

---

## Estructura del repo template
```
gpsf-infra-template/
├── README.md
├── docker-compose.yml
├── .env.example
├── nginx/
│   ├── n8n.conf.template
│   ├── qdrant.conf.template
│   └── pgadmin.conf.template
├── scripts/
│   ├── bootstrap.sh
│   ├── deploy.sh
│   ├── nginx_setup.sh
│   └── update_stack.sh
└── docs/
    └── PROCESS.md
```

---

# Paso a paso (VPS Hostinger LEMP)

## 0) Inputs mínimos (antes de tocar el VPS)
- `CLIENT_CODE` (ej: `ayv`)
- Email para certbot
- Subdominios a crear:
  - `n8n-CLIENT`
  - `qdrant-CLIENT`
  - `pgadmin-CLIENT`
- SSH public key del/los devs

---

## 1) DNS (lo hacés en el panel del dominio)
Crear A records (o CNAME si tenés LB, pero estándar A) para:
- `n8n-CLIENT` → IP del VPS
- `qdrant-CLIENT` → IP del VPS
- `pgadmin-CLIENT` → IP del VPS

---

## 2) Bootstrap del VPS (una sola vez por VPS)
Entras por root (solo para bootstrap inicial) y corrés:

```
bash scripts/bootstrap.sh
```

Qué hace:
- crea usuario `deploy`
- configura SSH hardening básico
- instala Docker + Compose plugin
- habilita UFW (22/80/443)
- prepara `/srv/stacks`

**DoD**:
- podés loguearte como `deploy`
- root por ssh deshabilitado
- password auth off
- UFW activo

---

## 3) Deploy del cliente (por cliente / por VPS)
Como `deploy`:

1) Clonar el repo dentro de la carpeta del cliente:
```
sudo mkdir -p /srv/stacks/<client>-prod
sudo chown -R deploy:deploy /srv/stacks/<client>-prod
cd /srv/stacks/<client>-prod
git clone <TU_REPO_TEMPLATE> .
```

2) Configurar `.env`:
```
cp .env.example .env
nano .env
```

3) Levantar stack:
```
bash scripts/deploy.sh
```

**DoD**:
- `docker compose ps` muestra servicios Up
- n8n responde en localhost:5678
- qdrant responde en localhost:6333
- pgadmin responde en localhost:5050

---

## 4) Nginx + SSL (host LEMP)
Como `deploy` (con sudo), corrés:

```
sudo bash scripts/nginx_setup.sh
```

Qué hace:
- genera server blocks desde templates (n8n/qdrant/pgadmin)
- los instala en `/etc/nginx/sites-available/`
- habilita symlinks en `sites-enabled`
- valida Nginx
- ejecuta certbot para los 3 subdominios
- recarga Nginx

**DoD**:
- https OK en los 3 subdominios
- n8n login carga
- qdrant dashboard carga
- pgadmin login carga

---

## 5) Defaults n8n (workflows)
Acciones en n8n:
- Importar workflow **Healthchecks** y activarlo.
- Configurar credencial del canal OPS (Telegram).
- Importar workflow **GPSF Error Bot** (con credenciales) pero dejarlo **desactivado**.

---

# Updates (mantener n8n al día)

## A) Update del stack (Docker images + compose)
Esto es lo que querés para n8n.

**Proceso estándar** (por cliente):
```
cd /srv/stacks/<client>-prod
bash scripts/update_stack.sh
```

Qué hace:
- `git pull`
- `docker compose pull`
- `docker compose up -d`
- smoke test básico (status + curl localhost)

**Rollback rápido**:
- Volvés al tag anterior del repo template y repetís `docker compose up -d`.

---

## B) Update Ubuntu / host Nginx (separado)
Regla:
- snapshot primero
- ventana de mantenimiento
- no mezclar con update de stack

---

# GitHub: cómo se usa en este sistema

## 1) Crear el repo template
- Creás un repo en GitHub: `gpsf-infra-template`
- Subís este template (todo el contenido)

## 2) Versionado
- Cada cambio relevante: tag
  - `v1.0.0`, `v1.0.1`, etc.
- Changelog en README o release notes.

## 3) “Control centralizado” de muchos VPS
GitHub **no controla** VPS por sí mismo.  
Lo que sí te da control central es:
- 1 repo template único
- mismas rutas en todos los VPS
- mismo script `update_stack.sh`

Para “centralizar” aún más:
- podés tener una lista de VPS y correr updates vía SSH desde una máquina “control” (más adelante).
- o usar Ansible (si querés nivel pro).
Pero para tu etapa: **innecesario**. Con disciplina de template + scripts, ya escalás.

---
