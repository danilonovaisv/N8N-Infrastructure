#!/usr/bin/env bash
set -euo pipefail
: "${DB_HOST?Missing DB_HOST}"
: "${DB_PORT:=5432}"
: "${DB_NAME?Missing DB_NAME}"
: "${DB_USER?Missing DB_USER}"
: "${DB_PASSWORD?Missing DB_PASSWORD}"
: "${DUMP_PATH?Usage: DUMP_PATH=/path/to/db.dump ./scripts/restore.sh}"
echo "==> Restoring Postgres from ${DUMP_PATH} ..."
# Important: Stop n8n before restoring to avoid corruption
echo "Make sure the n8n container is stopped before proceeding."
read -p "Press enter to continue or Ctrl+C to cancel."

export PGPASSWORD="${DB_PASSWORD}"
pg_restore -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" --clean --if-exists "${DUMP_PATH}"
echo "==> Done."
