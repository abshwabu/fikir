# Fikir Production Runbook & Operations Guide

This runbook provides complete operational procedures for deploying, maintaining, debugging, and recovering the Fikir platform on a single Linux VPS or scaling to multi-node clusters.

---

## 1. 30-Minute Fresh VPS Provisioning Guide

Follow these steps sequentially to bring a fresh Ubuntu 24.04 / 22.04 LTS VPS into a fully running production instance.

### Step 1: Base Host Setup & Docker Installation (5 min)
```bash
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y ca-certificates curl gnupg lsb-release ufw

# Configure UFW Firewall
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP (Certbot & redirect)
sudo ufw allow 443/tcp   # HTTPS
sudo ufw --force enable

# Install Docker & Docker Compose Plugin
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER
```

### Step 2: Clone Repository & Configure Environment (5 min)
```bash
git clone https://github.com/abshwabu/fikir.git /opt/fikir
cd /opt/fikir

# Create secure production environment file
cat <<EOF > .env.prod
APP_ENV=production
APP_PORT=8080
LOG_LEVEL=info

# Database
DB_USER=fikir_admin
DB_PASSWORD=$(openssl rand -hex 24)
DB_NAME=fikir

# Redis & Storage
REDIS_PASSWORD=$(openssl rand -hex 24)
MINIO_ROOT_USER=fikir_minio
MINIO_ROOT_PASSWORD=$(openssl rand -hex 24)
MINIO_BUCKET_ORIGINAL=fikir-media-original
MINIO_BUCKET_PUBLIC=fikir-media-public

# Authentication & Keys
JWT_SECRET=$(openssl rand -hex 32)

# Payment Rails (Chapa & Telebirr)
CHAPA_SECRET_KEY=CHASECK_TEST-your-chapa-secret-key
CHAPA_WEBHOOK_SECRET=your-webhook-secret

# Domain & SSL
DOMAIN=api.fikir.et
ADMIN_EMAIL=admin@fikir.et
EOF

chmod 600 .env.prod
```

### Step 3: Launch Production Stack (10 min)
```bash
# Start all databases, storage, and migration services
docker compose --env-file .env.prod -f docker-compose.prod.yml up -d --build

# Verify healthy startup
docker compose --env-file .env.prod -f docker-compose.prod.yml ps
```

### Step 4: Issue TLS Certificate with Let's Encrypt (5 min)
```bash
# Request initial Let's Encrypt certificate
docker compose --env-file .env.prod -f docker-compose.prod.yml run --rm certbot certonly \
  --webroot --webroot-path=/var/www/certbot \
  -d api.fikir.et \
  --email admin@fikir.et \
  --agree-tos --no-eff-email

# Reload Nginx with TLS enabled
docker compose --env-file .env.prod -f docker-compose.prod.yml exec nginx nginx -s reload
```

### Step 5: Verify Health & Metrics (5 min)
```bash
# Test healthz
curl -f https://api.fikir.et/healthz
# Expected: {"status":"ok", ...}

# Test discovery latency
curl -i https://api.fikir.et/api/healthz
```

---

## 2. Deploy & Rollback Procedures

### Standard Zero-Downtime Deployment
1. Pull new container images:
   ```bash
   docker compose --env-file .env.prod -f docker-compose.prod.yml pull api worker
   ```
2. Apply any pending database migrations:
   ```bash
   docker compose --env-file .env.prod -f docker-compose.prod.yml run --rm migrate up
   ```
3. Graceful rolling reload of API and worker:
   ```bash
   docker compose --env-file .env.prod -f docker-compose.prod.yml up -d --no-deps --scale api=2 --no-recreate api
   docker compose --env-file .env.prod -f docker-compose.prod.yml restart worker
   docker compose --env-file .env.prod -f docker-compose.prod.yml exec nginx nginx -s reload
   ```

### Emergency Rollback
1. Rollback code to previous container SHA or Git tag:
   ```bash
   TAG=v1.0.0 docker compose --env-file .env.prod -f docker-compose.prod.yml up -d api worker
   ```
2. If schema rollback is required:
   ```bash
   docker compose --env-file .env.prod -f docker-compose.prod.yml run --rm migrate down 1
   ```

---

## 3. Backup & Restore Drill

### Automated Daily Backups
The `db-backup` container runs `/backup.sh` every 24 hours. Backups are gzipped and retained for 30 days under `/backups`.

### Manual Backup On-Demand
```bash
docker compose --env-file .env.prod -f docker-compose.prod.yml exec db-backup /backup.sh
```

### Restore Drill Procedure
```bash
# Run restore drill script against test container or disaster recovery instance
docker compose --env-file .env.prod -f docker-compose.prod.yml exec db-backup \
  /bin/sh /deploy/scripts/restore_postgres.sh /backups/fikir_backup_latest.sql.gz
```

---

## 4. Incident Response Checklists

### Incident A: High API Latency / p95 Spike (> 200 ms)
1. Check Grafana dashboard `Fikir System Overview` at `http://<vps-ip>:3000`.
2. Inspect active DB connections:
   ```bash
   docker compose exec pgbouncer psql -p 6432 -U postgres -c "SHOW POOLS;"
   ```
3. Query `pg_stat_statements` for long-running slow queries:
   ```bash
   docker compose exec postgres psql -U postgres -d fikir -c "
     SELECT query, round(mean_exec_time::numeric, 2) AS avg_ms, calls 
     FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 5;
   "
   ```
4. If Redis CPU is high, check keys with high churn:
   ```bash
   docker compose exec redis redis-cli info stats
   ```

### Incident B: Payment Webhook Drop or Chapa Failure
1. Inspect webhook logs in Loki / Promtail:
   `{service="fikir-api"} |= "chapa" |= "webhook"`
2. Verify Redis distributed lock status:
   `docker compose exec redis redis-cli keys "payment:lock:*"`
3. Force payment reconciliation worker to run:
   The periodic worker automatically syncs pending transactions every 10 minutes.

### Incident C: WebSocket Disconnection Storms
1. Check `fikir_ws_active_connections` metric.
2. Check Nginx error log for file descriptor limits:
   `docker compose logs --tail=100 nginx | grep -i "worker_connections"`
3. Ensure client auto-reconnect backoff has jitter applied (implemented in Flutter `websocket_manager.dart`).
