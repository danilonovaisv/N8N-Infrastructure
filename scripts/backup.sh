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
OUTDIR="workflows/backup/${TS}"
mkdir -p "$OUTDIR"

echo "==> Dumping Postgres (Supabase) ..."
export PGPASSWORD="${DB_PASSWORD}"
pg_dump -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -F c -Z 5 -f "${OUTDIR}/db.dump"

echo "==> Exporting n8n workflows ..."
curl -sS -H "X-N8N-API-KEY: ${N8N_API_KEY}"       "${N8N_BASE_URL}/rest/workflows" > "${OUTDIR}/workflows.json"

echo "==> Done. Artifacts at ${OUTDIR}"
