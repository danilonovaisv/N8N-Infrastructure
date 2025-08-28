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

DATE_STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR_DB="$ROOT_DIR/backups/db"
BACKUP_DIR_WF="$ROOT_DIR/workflows/backup"
mkdir -p "$BACKUP_DIR_DB" "$BACKUP_DIR_WF"

echo "==> Backing up Supabase Postgres (SSL required)"
if [[ -z "${DB_POSTGRESDB_HOST:-}" || -z "${DB_POSTGRESDB_DATABASE:-}" || -z "${DB_POSTGRESDB_USER:-}" || -z "${DB_POSTGRESDB_PASSWORD:-}" ]]; then
  echo "Database env vars missing. Check config/.env" >&2
  exit 1
fi

export PGPASSWORD="$DB_POSTGRESDB_PASSWORD"
pg_dump \
  --host="$DB_POSTGRESDB_HOST" \
  --port="${DB_POSTGRESDB_PORT:-5432}" \
  --username="$DB_POSTGRESDB_USER" \
  --dbname="$DB_POSTGRESDB_DATABASE" \
  --format=plain \
  --no-owner \
  --no-privileges \
  --verbose \
  --sslmode=require \
  > "$BACKUP_DIR_DB/db-backup-$DATE_STAMP.sql"

echo "==> Exporting n8n workflows via API"
if [[ -z "${N8N_URL:-}" || -z "${N8N_API_KEY:-}" ]]; then
  echo "N8N_URL or N8N_API_KEY missing. Skipping workflows export." >&2
else
  # List workflows
  WF_LIST_JSON="$(curl -fsSL -H "X-N8N-API-KEY: $N8N_API_KEY" "$N8N_URL/rest/workflows")"
  echo "$WF_LIST_JSON" | jq -c '.data[]' | while read -r wf; do
    ID="$(echo "$wf" | jq -r '.id')"
    NAME="$(echo "$wf" | jq -r '.name' | tr ' /' '__')"
    echo "  - Exporting workflow $ID: $NAME"
    curl -fsSL -H "X-N8N-API-KEY: $N8N_API_KEY" \
      "$N8N_URL/rest/workflows/$ID" \
      | jq '.' > "$BACKUP_DIR_WF/${DATE_STAMP}-${ID}-${NAME}.json"
  done
fi

echo "==> Backup completed"

