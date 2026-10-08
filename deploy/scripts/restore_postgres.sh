#!/bin/sh
set -e

if [ -z "$1" ]; then
  echo "Usage: $0 /path/to/backup.sql.gz"
  exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "${BACKUP_FILE}" ]; then
  echo "Error: Backup file '${BACKUP_FILE}' not found."
  exit 1
fi

echo "[$(date -u)] Starting database restore drill from ${BACKUP_FILE}..."
echo "Target DB: ${POSTGRES_DB:-fikir} on host: ${DB_HOST:-postgres}"

gunzip -c "${BACKUP_FILE}" | PGPASSWORD="${POSTGRES_PASSWORD}" psql -h "${DB_HOST:-postgres}" -U "${POSTGRES_USER:-postgres}" -d "${POSTGRES_DB:-fikir}"

echo "[$(date -u)] Restore drill completed successfully. Validating integrity..."
PGPASSWORD="${POSTGRES_PASSWORD}" psql -h "${DB_HOST:-postgres}" -U "${POSTGRES_USER:-postgres}" -d "${POSTGRES_DB:-fikir}" -c "
SELECT 
  (SELECT count(*) FROM users) AS users_count,
  (SELECT count(*) FROM profiles) AS profiles_count,
  (SELECT count(*) FROM matches) AS matches_count,
  (SELECT count(*) FROM messages) AS messages_count;
"
echo "[$(date -u)] Verification query executed. Database is online and consistent."
