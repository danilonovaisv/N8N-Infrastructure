#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/config/.env"

if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
else
  echo "Env file not found at $ENV_FILE" >&2
  exit 1
fi

SQL_FILE="${1:-}"
if [ -z "$SQL_FILE" ] || [ ! -f "$SQL_FILE" ]; then
  echo "Usage: $0 path/to/backup.sql" >&2
  exit 1
fi

if [[ -z "${DB_POSTGRESDB_HOST:-}" || -z "${DB_POSTGRESDB_DATABASE:-}" || -z "${DB_POSTGRESDB_USER:-}" || -z "${DB_POSTGRESDB_PASSWORD:-}" ]]; then
  echo "Database env vars missing. Check config/.env" >&2
  exit 1
fi

echo "==> Restoring database from $SQL_FILE"
export PGPASSWORD="$DB_POSTGRESDB_PASSWORD"
psql \
  --host="$DB_POSTGRESDB_HOST" \
  --port="${DB_POSTGRESDB_PORT:-5432}" \
  --username="$DB_POSTGRESDB_USER" \
  --dbname="$DB_POSTGRESDB_DATABASE" \
  --set ON_ERROR_STOP=on \
  --set sslmode=require \
  --file "$SQL_FILE"

echo "==> Restore completed"

