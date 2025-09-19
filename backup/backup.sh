#!/usr/bin/env bash
set -euo pipefail

NOW="$(date +'%Y-%m-%d_%H-%M-%S')"
BACKUP_DIR="/backups/${NOW}"
mkdir -p "${BACKUP_DIR}"

echo "[*] Dumpando Postgres..."
PGPASSWORD="${DB_POSTGRESDB_PASSWORD}" pg_dump \
  -h "${DB_POSTGRESDB_HOST}" -p "${DB_POSTGRESDB_PORT:-5432}" \
  -U "${DB_POSTGRESDB_USER}" \
  -d "${DB_POSTGRESDB_DATABASE}" \
  -F c -Z 9 -f "${BACKUP_DIR}/postgres.dump"

echo "[*] Exportando dados do n8n..."
if [[ -n "${N8N_API_KEY:-}" ]]; then
  curl -fsS -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
    "http://n8n:5678/rest/workflows" \
    -o "${BACKUP_DIR}/workflows.json" || true
  curl -fsS -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
    "http://n8n:5678/rest/credentials" \
    -o "${BACKUP_DIR}/credentials.json" || true
fi

echo "[*] Compactando..."
tar -C "/backups" -czf "/backups/n8n-backup-${NOW}.tar.gz" "${NOW}"
rm -rf "${BACKUP_DIR}"

echo "[✓] Backup finalizado: /backups/n8n-backup-${NOW}.tar.gz"
