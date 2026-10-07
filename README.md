# Fikir (ፍቅር)

A Tinder-style dating application crafted for the Ethiopian market.

- **Backend**: Go (Gin / standard library / PostGIS / Redis)
- **Mobile**: Flutter (iOS & Android)
- **Infrastructure**: Docker Compose, PostgreSQL 16 + PostGIS, Redis 7, MinIO, Nginx

---

## Repository Structure

```
fikir/
  backend/            # Go backend services (api, worker, seed, migrations)
    cmd/
      api/            # REST and WebSocket API entrypoint
      worker/         # Async worker entrypoint (jobs, media, notifications)
      seed/           # Database seeding utility
    migrations/       # golang-migrate SQL migrations
    .air.toml         # Air hot reload config
    Dockerfile        # Multi-stage container build
    go.mod            # Go module declaration
  mobile/             # Flutter client application placeholder
    README.md
  deploy/
    docker/           # Shared Docker infrastructure assets & entrypoints
      postgres/       # DB init scripts (PostGIS, pg_trgm extensions)
      migrate/        # Golang-migrate wrapper entrypoint
    nginx/            # Reverse proxy configuration
      nginx.conf      # Base / dev configuration
      conf.d/prod.conf# Production TLS / Certbot configuration
  docker-compose.yml     # Base Docker Compose services
  docker-compose.dev.yml # Development overrides (Air hot-reload, exposed ports, pgAdmin)
  docker-compose.prod.yml# Production overrides (resource limits, TLS, restart policies)
  Makefile               # Common tasks and lifecycle commands
  .env.example           # Complete environment variable template
  README.md
```

---

## Quickstart

### 1. Copy Environment Variables

```bash
cp .env.example .env
```

### 2. Start Services

```bash
make up
```

All services will build and start in detached mode.

### 3. Verify Health

```bash
curl http://localhost/api/healthz
```

Expected output:
```json
{"status":"ok","service":"fikir-api","timestamp":"..."}
```

---

## Infrastructure Services

| Service | Image / Base | Internal Port | Dev Port | Description |
| :--- | :--- | :--- | :--- | :--- |
| **api** | Alpine / Go 1.24 | 8080 | 8080 | Go REST / WebSocket API (`air` hot-reload in dev) |
| **worker** | Alpine / Go 1.24 | - | - | Asynchronous background worker |
| **postgres** | `postgis/postgis:16-3.4` | 5432 | 5432 | PostgreSQL with `postgis` & `pg_trgm` extensions |
| **redis** | `redis:7-alpine` | 6379 | 6379 | In-memory cache & queues (AOF off, LRU eviction) |
| **minio** | `minio/minio:latest` | 9000, 9001 | 9000, 9001 | S3-compatible object storage |
| **minio-init** | `minio/mc:latest` | - | - | One-shot bucket initializer (`original` & `public`) |
| **migrate** | `migrate/migrate:v4.17.1` | - | - | One-shot database schema migrator |
| **nginx** | `nginx:1.27-alpine` | 80 | 80 | Reverse proxy (`/api`, `/ws`, cached `/media`) |
| **pgadmin** | `dpage/pgadmin4:latest` | 80 | 5050 | Web UI for PostgreSQL (`--profile pgadmin`) |

---

## Makefile Targets

| Command | Description |
| :--- | :--- |
| `make up` | Build and start infrastructure in detached mode (`dev` profile) |
| `make down` | Stop and remove all containers and networks |
| `make logs` | Follow logs from all running services |
| `make migrate-up` | Run pending database migrations |
| `make migrate-down` | Roll back the most recent migration |
| `make seed` | Execute the database seed runner |
| `make test` | Run backend Go unit and integration tests |
| `make lint` | Run Go vet / static analysis |
| `make build-apk` | Build Flutter Android APK in a clean Docker container |

---

## Development vs Production

- **Development (`docker-compose.dev.yml`)**:
  - Hot reload enabled for the Go backend via `air`.
  - Service ports directly exposed to `localhost` (Postgres on 5432, Redis on 6379, MinIO on 9000/9001).
  - Optional `pgadmin` service available with `docker compose --profile pgadmin up -d`.

- **Production (`docker-compose.prod.yml`)**:
  - CPU and memory limits on all containers.
  - Strict restart policies (`restart: always`).
  - No database or Redis ports exposed to host; all ingress routed through Nginx.
  - Nginx TLS configuration ready for Let's Encrypt / Certbot automated certificates.
