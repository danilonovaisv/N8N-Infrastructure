@@ .. @@
 #!/usr/bin/env bash
 set -euo pipefail
 
+# Cleanup function to ensure sensitive variables are unset
+cleanup() {
+  unset PGPASSWORD 2>/dev/null || true
+  echo "==> Cleanup completed"
+}
+
+# Set trap for cleanup on exit
+trap cleanup EXIT
+
 ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
 ENV_FILE="$ROOT_DIR/config/.env"
 
@@ .. @@
 DATE_STAMP="$(date +%Y%m%d-%H%M%S)"
 BACKUP_DIR_DB="$ROOT_DIR/backups/db"
 BACKUP_DIR_WF="$ROOT_DIR/workflows/backup"
 mkdir -p "$BACKUP_DIR_DB" "$BACKUP_DIR_WF"
 
+# Validate required environment variables
+if [[ -z "${DB_POSTGRESDB_HOST:-}" || -z "${DB_POSTGRESDB_DATABASE:-}" || -z "${DB_POSTGRESDB_USER:-}" || -z "${DB_POSTGRESDB_PASSWORD:-}" ]]; then
+  echo "❌ Database environment variables missing. Check config/.env" >&2
+  echo "Required: DB_POSTGRESDB_HOST, DB_POSTGRESDB_DATABASE, DB_POSTGRESDB_USER, DB_POSTGRESDB_PASSWORD" >&2
+  exit 1
+fi
+
 echo "==> Backing up Supabase Postgres (SSL required)"
-if [[ -z "${DB_POSTGRESDB_HOST:-}" || -z "${DB_POSTGRESDB_DATABASE:-}" || -z "${DB_POSTGRESDB_USER:-}" || -z "${DB_POSTGRESDB_PASSWORD:-}" ]]; then
-  echo "Database env vars missing. Check config/.env" >&2
-  exit 1
-fi
 
+# Set password for pg_dump (will be cleaned up by trap)
 export PGPASSWORD="$DB_POSTGRESDB_PASSWORD"
+
+# Create backup with compression and proper permissions
+BACKUP_FILE="$BACKUP_DIR_DB/db-backup-$DATE_STAMP.sql"
 pg_dump \
   --host="$DB_POSTGRESDB_HOST" \
   --port="${DB_POSTGRESDB_PORT:-5432}" \
@@ .. @@
   --no-privileges \
   --verbose \
   --sslmode=require \
-  > "$BACKUP_DIR_DB/db-backup-$DATE_STAMP.sql"
+  > "$BACKUP_FILE"
+
+# Set secure permissions on backup file
+chmod 600 "$BACKUP_FILE"
+
+# Compress backup to save space
+gzip "$BACKUP_FILE"
+echo "==> Database backup created: ${BACKUP_FILE}.gz"
 
 echo "==> Exporting n8n workflows via API"
 if [[ -z "${N8N_URL:-}" || -z "${N8N_API_KEY:-}" ]]; then
@@ .. @@
   # List workflows
   WF_LIST_JSON="$(curl -fsSL -H "X-N8N-API-KEY: $N8N_API_KEY" "$N8N_URL/rest/workflows")"
   echo "$WF_LIST_JSON" | jq -c '.data[]' | while read -r wf; do
     ID="$(echo "$wf" | jq -r '.id')"
     NAME="$(echo "$wf" | jq -r '.name' | tr ' /' '__')"
     echo "  - Exporting workflow $ID: $NAME"
+    WF_FILE="$BACKUP_DIR_WF/${DATE_STAMP}-${ID}-${NAME}.json"
     curl -fsSL -H "X-N8N-API-KEY: $N8N_API_KEY" \
       "$N8N_URL/rest/workflows/$ID" \
-      | jq '.' > "$BACKUP_DIR_WF/${DATE_STAMP}-${ID}-${NAME}.json"
+      | jq '.' > "$WF_FILE"
+    # Set secure permissions on workflow files
+    chmod 600 "$WF_FILE"
   done
+  
+  # Create a consolidated backup archive
+  ARCHIVE_FILE="$ROOT_DIR/backups/n8n-backup-$DATE_STAMP.tar.gz"
+  tar -czf "$ARCHIVE_FILE" -C "$ROOT_DIR" \
+    "backups/db/db-backup-$DATE_STAMP.sql.gz" \
+    "workflows/backup/${DATE_STAMP}-"*.json \
+    "config" 2>/dev/null || true
+  
+  chmod 600 "$ARCHIVE_FILE"
+  echo "==> Complete backup archive created: $ARCHIVE_FILE"
 fi
 
-echo "==> Backup completed"
+echo "==> Backup completed successfully"
+echo "==> Files created:"
+echo "   - Database: ${BACKUP_FILE}.gz"
+echo "   - Workflows: $BACKUP_DIR_WF/${DATE_STAMP}-*.json"
+if [[ -f "$ARCHIVE_FILE" ]]; then
+  echo "   - Archive: $ARCHIVE_FILE"
+fi