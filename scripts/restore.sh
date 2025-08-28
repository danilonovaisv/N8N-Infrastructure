#!/usr/bin/env bash
set -euo pipefail

# Cleanup function to ensure sensitive variables are unset
cleanup() {
  unset PGPASSWORD 2>/dev/null || true
  echo "==> Cleanup completed"
}

# Set trap for cleanup on exit
trap cleanup EXIT

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/config/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "Environment file not found: $ENV_FILE" >&2
  exit 1
fi

BACKUP_INPUT="${1:-}"
if [ -z "$BACKUP_INPUT" ]; then
  echo "Usage: $0 <backup-file>" >&2
  echo "  backup-file can be:" >&2
  echo "    - path/to/backup.sql (SQL dump)" >&2
  echo "    - path/to/backup.sql.gz (compressed SQL dump)" >&2
  echo "    - path/to/n8n-backup-YYYYMMDD-HHMMSS.tar.gz (full archive)" >&2
  exit 1
fi

if [ ! -f "$BACKUP_INPUT" ]; then
  echo "❌ Backup file not found: $BACKUP_INPUT" >&2
  exit 1
fi

# Validate database connection parameters
if [[ -z "${DB_POSTGRESDB_HOST:-}" || -z "${DB_POSTGRESDB_DATABASE:-}" || -z "${DB_POSTGRESDB_USER:-}" || -z "${DB_POSTGRESDB_PASSWORD:-}" ]]; then
  echo "❌ Database environment variables missing. Check config/.env" >&2
  echo "Required: DB_POSTGRESDB_HOST, DB_POSTGRESDB_DATABASE, DB_POSTGRESDB_USER, DB_POSTGRESDB_PASSWORD" >&2
  exit 1
fi

# Determine backup type and prepare for restoration
TEMP_DIR="/tmp/n8n-restore-$$"
mkdir -p "$TEMP_DIR"

# Cleanup temp directory on exit
cleanup_temp() {
  rm -rf "$TEMP_DIR"
  cleanup
}
trap cleanup_temp EXIT

SQL_FILE=""

if [[ "$BACKUP_INPUT" == *.tar.gz ]]; then
  echo "==> Extracting full backup archive: $BACKUP_INPUT"
  tar -xzf "$BACKUP_INPUT" -C "$TEMP_DIR"
  
  # Find the SQL file in the extracted archive
  SQL_FILE=$(find "$TEMP_DIR" -name "*.sql.gz" -o -name "*.sql" | head -1)
  if [ -z "$SQL_FILE" ]; then
    echo "❌ No SQL dump found in archive" >&2
    exit 1
  fi
elif [[ "$BACKUP_INPUT" == *.sql.gz ]]; then
  echo "==> Decompressing SQL backup: $BACKUP_INPUT"
  gunzip -c "$BACKUP_INPUT" > "$TEMP_DIR/backup.sql"
  SQL_FILE="$TEMP_DIR/backup.sql"
elif [[ "$BACKUP_INPUT" == *.sql ]]; then
  SQL_FILE="$BACKUP_INPUT"
else
  echo "❌ Unsupported backup file format: $BACKUP_INPUT" >&2
  echo "Supported formats: .sql, .sql.gz, .tar.gz" >&2
  exit 1
fi

# Verify SQL file exists and is readable
if [ ! -f "$SQL_FILE" ] || [ ! -r "$SQL_FILE" ]; then
  echo "❌ SQL file not found or not readable: $SQL_FILE" >&2
  exit 1
fi

# Warning about destructive operation
echo "⚠️  WARNING: This will overwrite your existing database!"
echo "Database: ${DB_POSTGRESDB_HOST}:${DB_POSTGRESDB_PORT:-5432}/${DB_POSTGRESDB_DATABASE}"
echo "SQL File: $SQL_FILE"
echo ""
read -p "Are you sure you want to continue? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
  echo "==> Restore cancelled by user"
  exit 0
fi

# Test database connection before proceeding
echo "==> Testing database connection..."
export PGPASSWORD="$DB_POSTGRESDB_PASSWORD"

if ! pg_isready -h "$DB_POSTGRESDB_HOST" -p "${DB_POSTGRESDB_PORT:-5432}" -U "$DB_POSTGRESDB_USER" -d "$DB_POSTGRESDB_DATABASE"; then
  echo "❌ Cannot connect to database" >&2
  exit 1
fi

echo "✅ Database connection successful"

# Create a safety backup before restoration
SAFETY_BACKUP="$ROOT_DIR/backups/pre-restore-$(date +%Y%m%d-%H%M%S).sql.gz"
echo "==> Creating safety backup before restore: $SAFETY_BACKUP"
mkdir -p "$(dirname "$SAFETY_BACKUP")"

pg_dump \
  --host="$DB_POSTGRESDB_HOST" \
  --port="${DB_POSTGRESDB_PORT:-5432}" \
  --username="$DB_POSTGRESDB_USER" \
  --dbname="$DB_POSTGRESDB_DATABASE" \
  --format=plain \
  --no-owner \
  --no-privileges \
  --sslmode=require | gzip > "$SAFETY_BACKUP"

chmod 600 "$SAFETY_BACKUP"
echo "✅ Safety backup created: $SAFETY_BACKUP"

# Perform the restoration
echo "==> Restoring database from $SQL_FILE"
psql \
  --host="$DB_POSTGRESDB_HOST" \
  --port="${DB_POSTGRESDB_PORT:-5432}" \
  --username="$DB_POSTGRESDB_USER" \
  --dbname="$DB_POSTGRESDB_DATABASE" \
  --set ON_ERROR_STOP=on \
  --set sslmode=require \
  --file "$SQL_FILE"

echo "✅ Database restore completed successfully"

# If this was a full archive, restore workflows and config
if [[ "$BACKUP_INPUT" == *.tar.gz ]]; then
  echo "==> Checking for additional restore items..."
  
  # Look for workflow files
  WORKFLOW_FILES=$(find "$TEMP_DIR" -name "*.json" -path "*/workflows/backup/*" 2>/dev/null || true)
  if [ -n "$WORKFLOW_FILES" ]; then
    echo "==> Found workflow files for manual import:"
    echo "$WORKFLOW_FILES" | while read -r wf_file; do
      echo "   - $(basename "$wf_file")"
    done
    echo "💡 Import these manually through the n8n UI or API"
  fi
  
  # Look for config files
  CONFIG_DIR="$TEMP_DIR/config"
  if [ -d "$CONFIG_DIR" ]; then
    echo "==> Found configuration backup"
    echo "⚠️  Review and manually restore config files if needed:"
    find "$CONFIG_DIR" -type f | while read -r config_file; do
      echo "   - $(basename "$config_file")"
    done
  fi
fi

echo ""
echo "==> Restore Summary:"
echo "✅ Database restored from: $SQL_FILE"
echo "✅ Safety backup created: $SAFETY_BACKUP"
if [[ "$BACKUP_INPUT" == *.tar.gz ]]; then
  echo "💡 Manual steps may be required for workflows and configuration"
fi
echo "🔄 Restart n8n to apply changes"