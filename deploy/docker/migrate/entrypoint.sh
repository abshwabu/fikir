#!/bin/sh
set -e

DB_HOST="${DB_HOST:-postgres}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD:-postgres}"
DB_NAME="${DB_NAME:-fikir}"
DB_SSLMODE="${DB_SSLMODE:-disable}"

DB_URL="postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=${DB_SSLMODE}"
MIGRATIONS_DIR="${MIGRATIONS_DIR:-/migrations}"

ACTION="${1:-up}"
shift 1 || true

echo "Waiting for PostgreSQL at ${DB_HOST}:${DB_PORT}..."
until nc -z "${DB_HOST}" "${DB_PORT}"; do
  echo "PostgreSQL port not open yet - sleeping 1s"
  sleep 1
done

retries=15
while [ $retries -gt 0 ]; do
  if /migrate -path="${MIGRATIONS_DIR}" -database="${DB_URL}" "${ACTION}" "$@"; then
    echo "Migration completed successfully"
    exit 0
  fi
  echo "Migration failed, retrying in 2 seconds ($retries attempts left)..."
  sleep 2
  retries=$((retries - 1))
done

echo "Migration failed after multiple attempts"
exit 1
