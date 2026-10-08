#!/bin/sh
set -e

BACKUP_DIR="/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
FILENAME="${BACKUP_DIR}/fikir_backup_${TIMESTAMP}.sql.gz"
RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-30}

mkdir -p "${BACKUP_DIR}"

echo "[$(date -u)] Starting daily PostgreSQL backup for ${POSTGRES_DB}..."
PGPASSWORD="${POSTGRES_PASSWORD}" pg_dump -h postgres -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" --no-owner --clean | gzip > "${FILENAME}"

BACKUP_SIZE=$(du -h "${FILENAME}" | cut -f1)
echo "[$(date -u)] Backup created successfully: ${FILENAME} (${BACKUP_SIZE})"

# Prune backups older than RETENTION_DAYS
echo "[$(date -u)] Pruning backups older than ${RETENTION_DAYS} days..."
find "${BACKUP_DIR}" -type f -name "fikir_backup_*.sql.gz" -mtime +${RETENTION_DAYS} -delete

echo "[$(date -u)] Daily backup routine completed."
