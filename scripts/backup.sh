#!/usr/bin/env bash
set -euo pipefail

: "${DB_HOST?Missing DB_HOST}"
: "${DB_PORT:=5432}"
: "${DB_NAME?Missing DB_NAME}"
: "${DB_USER?Missing DB_USER}"
: "${DB_PASSWORD?Missing DB_PASSWORD}"
: "${N8N_BASE_URL?Missing N8N_BASE_URL}"
: "${N8N_API_KEY?Missing N8N_API_KEY}"

TS=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="n8n-backup-${TS}"
OUTDIR="workflows/backup/${BACKUP_NAME}"
mkdir -p "$OUTDIR"

# Use .pgpass for security
PGPASS_FILE=$(mktemp)
trap 'rm -f "$PGPASS_FILE"' EXIT # Ensure cleanup
echo "${DB_HOST}:${DB_PORT}:${DB_NAME}:${DB_USER}:${DB_PASSWORD}" > "${PGPASS_FILE}"
chmod 600 "${PGPASS_FILE}"
export PGPASSFILE="${PGPASS_FILE}"

echo "==> Dumping Postgres (Supabase) ..."
pg_dump -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -F c -Z 5 -f "${OUTDIR}/db.dump"

echo "==> Exporting n8n workflows ..."
curl -sS -H "X-N8N-API-KEY: ${N8N_API_KEY}" "${N8N_BASE_URL}/rest/workflows" > "${OUTDIR}/workflows.json"

echo "==> Backing up n8n config and credentials ..."
# We assume the script is run from the repo root, and config is in ./config
if [ -d "config" ]; then
  # Exclude .env if it exists, as it's for local dev
  rsync -av --exclude '.env' config/ "${OUTDIR}/config/"
else
  echo "Warning: 'config' directory not found. Skipping credentials backup."
fi

echo "==> Creating backup archive ..."
tar -czf "workflows/backup/${BACKUP_NAME}.tar.gz" -C "workflows/backup" "${BACKUP_NAME}"

# Clean up temporary directory
rm -rf "${OUTDIR}"

echo "==> Done. Backup created at workflows/backup/${BACKUP_NAME}.tar.gz"
