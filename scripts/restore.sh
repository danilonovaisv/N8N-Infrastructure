#!/usr/bin/env bash
set -euo pipefail

: "${DB_HOST?Missing DB_HOST}"
: "${DB_PORT:=5432}"
: "${DB_NAME?Missing DB_NAME}"
: "${DB_USER?Missing DB_USER}"
: "${DB_PASSWORD?Missing DB_PASSWORD}"
: "${BACKUP_FILE?Usage: BACKUP_FILE=/path/to/backup.tar.gz ./scripts/restore.sh}"

if [ ! -f "${BACKUP_FILE}" ]; then
  echo "Error: Backup file not found at ${BACKUP_FILE}"
  exit 1
fi

# Extract backup name from file path
BACKUP_NAME=$(basename "${BACKUP_FILE}" .tar.gz)
TMP_DIR="workflows/backup/${BACKUP_NAME}"

# 1. Extract backup
echo "==> Extracting backup archive ..."
mkdir -p "${TMP_DIR}"
tar -xzf "${BACKUP_FILE}" -C "workflows/backup"

DUMP_FILE="${TMP_DIR}/db.dump"
if [ ! -f "${DUMP_FILE}" ]; then
  echo "Error: db.dump not found in backup archive."
  rm -rf "${TMP_DIR}"
  exit 1
fi

# 2. Restore Database
# Use .pgpass for security
PGPASS_FILE=$(mktemp)
trap 'rm -f "$PGPASS_FILE" "$TMP_DIR"' EXIT # Ensure cleanup
echo "${DB_HOST}:${DB_PORT}:${DB_NAME}:${DB_USER}:${DB_PASSWORD}" > "${PGPASS_FILE}"
chmod 600 "${PGPASS_FILE}"
export PGPASSFILE="${PGPASS_FILE}"

echo "==> Restoring Postgres database ..."
pg_restore -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" --clean --if-exists "${DUMP_FILE}"

# 3. Restore Config
echo "==> Restoring n8n config and credentials ..."
if [ -d "${TMP_DIR}/config" ]; then
  # Important: Stop n8n before replacing config files to avoid corruption
  echo "Make sure the n8n container is stopped before proceeding."
  read -p "Press enter to continue"

  rsync -av --delete "${TMP_DIR}/config/" "config/"
  echo "Config restored. Please restart the n8n container."
else
  echo "Warning: 'config' directory not found in backup. Skipping."
fi

# 4. Restore Workflows
echo "==> Restoring n8n workflows ..."
if [ -f "${TMP_DIR}/workflows.json" ]; then
  # n8n can automatically load workflows from the /workflows directory
  # We need to split the JSON array into individual files
  # This is complex in bash, so we'll provide the file for manual import
  # and add instructions in the README
  cp "${TMP_DIR}/workflows.json" "workflows/restored_workflows_${BACKUP_NAME}.json"
  echo "Workflows JSON saved to workflows/restored_workflows_${BACKUP_NAME}.json"
  echo "Please import them manually via the n8n UI or use the n8n-cli."
else
  echo "Warning: 'workflows.json' not found in backup. Skipping."
fi

echo "==> Restore complete."
