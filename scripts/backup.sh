#!/usr/bin/env bash
set -euo pipefail

# Cleanup function to ensure sensitive variables are unset
cleanup() {
  unset PGPASSWORD 2>/dev/null || true
}
trap cleanup EXIT

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/config/.env"

# Load environment file if present
if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

DATE_STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR_DB="$ROOT_DIR/backups/db"
BACKUP_DIR_WF="$ROOT_DIR/workflows/backup"
mkdir -p "$BACKUP_DIR_DB" "$BACKUP_DIR_WF"

echo "==> Backing up Supabase Postgres (if DB_* vars present)"
DB_OK=1
if [[ -z "${DB_POSTGRESDB_HOST:-}" || -z "${DB_POSTGRESDB_DATABASE:-}" || -z "${DB_POSTGRESDB_USER:-}" || -z "${DB_POSTGRESDB_PASSWORD:-}" ]]; then
  echo "   Skipping DB backup: missing one or more DB_POSTGRESDB_* variables"
  DB_OK=0
fi

ARCHIVE_FILE=""
BACKUP_FILE=""

if [[ $DB_OK -eq 1 ]]; then
  export PGPASSWORD="$DB_POSTGRESDB_PASSWORD"
  BACKUP_FILE="$BACKUP_DIR_DB/db-backup-$DATE_STAMP.sql"
  pg_dump \
    --host="$DB_POSTGRESDB_HOST" \
    --port="${DB_POSTGRESDB_PORT:-6543}" \
    --username="$DB_POSTGRESDB_USER" \
    --dbname="$DB_POSTGRESDB_DATABASE" \
    --format=plain \
    --no-owner \
    --no-privileges \
    --verbose \
    --sslmode=require \
    > "$BACKUP_FILE"
  chmod 600 "$BACKUP_FILE"
  gzip "$BACKUP_FILE"
  echo "   DB backup: ${BACKUP_FILE}.gz"
fi

echo "==> Exporting n8n workflows via API (if N8N_* vars present)"
N8N_URL_COMBINED="${N8N_URL:-${N8N_BASE_URL:-}}"
if [[ -z "${N8N_URL_COMBINED}" || -z "${N8N_API_KEY:-}" ]]; then
  echo "   Skipping workflows export: missing N8N_BASE_URL/N8N_URL or N8N_API_KEY"
else
  WF_LIST_JSON="$(curl -fsSL -H "X-N8N-API-KEY: $N8N_API_KEY" "${N8N_URL_COMBINED%/}/rest/workflows")"
  echo "$WF_LIST_JSON" | jq -c '.data[]' | while read -r wf; do
    ID="$(echo "$wf" | jq -r '.id')"
    NAME="$(echo "$wf" | jq -r '.name' | tr ' /' '__')"
    echo "  - Exporting workflow $ID: $NAME"
    WF_FILE="$BACKUP_DIR_WF/${DATE_STAMP}-${ID}-${NAME}.json"
    curl -fsSL -H "X-N8N-API-KEY: $N8N_API_KEY" \
      "${N8N_URL_COMBINED%/}/rest/workflows/$ID" \
      | jq '.' > "$WF_FILE"
    chmod 600 "$WF_FILE"
  done

  # Create consolidated archive if DB backup also present
  ARCHIVE_FILE="$ROOT_DIR/backups/n8n-backup-$DATE_STAMP.tar.gz"
  tar -czf "$ARCHIVE_FILE" -C "$ROOT_DIR" \
    $( [[ -n "$BACKUP_FILE" ]] && echo "backups/db/$(basename "$BACKUP_FILE").gz" ) \
    "workflows/backup/${DATE_STAMP}-"*.json \
    "config" 2>/dev/null || true
  chmod 600 "$ARCHIVE_FILE" || true
  echo "==> Archive: $ARCHIVE_FILE"
fi

echo "==> Backup complete"
[[ -n "$BACKUP_FILE" ]] && echo "   DB: ${BACKUP_FILE}.gz"
echo "   Workflows dir: $BACKUP_DIR_WF"
[[ -f "$ARCHIVE_FILE" ]] && echo "   Archive: $ARCHIVE_FILE"

