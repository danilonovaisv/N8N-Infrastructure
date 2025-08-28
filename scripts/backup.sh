#!/bin/bash

# n8n Infrastructure Backup Script
# Backs up workflows, credentials, and configurations
# Usage: ./backup.sh [backup-name]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_ROOT/workflows/backup"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="${1:-n8n_backup_$TIMESTAMP}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is running
check_docker() {
    if ! docker ps > /dev/null 2>&1; then
        log_error "Docker is not running or accessible"
        exit 1
    fi
}

# Create backup directory
create_backup_dir() {
    local backup_path="$BACKUP_DIR/$BACKUP_NAME"
    mkdir -p "$backup_path"
    echo "$backup_path"
}

# Backup n8n workflows via API
backup_workflows() {
    local backup_path="$1"
    local container_name="n8n-automation"
    
    log_info "Backing up n8n workflows..."
    
    if docker ps --format '{{.Names}}' | grep -q "^$container_name$"; then
        # Export workflows using n8n CLI inside container
        docker exec "$container_name" n8n export:workflow --all --output="/home/node/.n8n/backup/workflows_$TIMESTAMP.json" || {
            log_warn "Failed to export workflows via CLI, trying API approach"
            return 1
        }
        
        # Copy exported file to backup directory
        docker cp "$container_name:/home/node/.n8n/backup/workflows_$TIMESTAMP.json" "$backup_path/"
        log_info "Workflows backed up successfully"
    else
        log_error "n8n container not found or not running"
        return 1
    fi
}

# Backup credentials (encrypted)
backup_credentials() {
    local backup_path="$1"
    local container_name="n8n-automation"
    
    log_info "Backing up encrypted credentials..."
    
    if docker ps --format '{{.Names}}' | grep -q "^$container_name$"; then
        docker cp "$container_name:/home/node/.n8n/credentials" "$backup_path/" 2>/dev/null || {
            log_warn "No credentials found or access denied"
        }
    fi
}

# Backup database schema and essential data
backup_database() {
    local backup_path="$1"
    
    log_info "Backing up database schema..."
    
    if [[ -n "${DB_POSTGRESDB_PASSWORD:-}" ]]; then
        export PGPASSWORD="$DB_POSTGRESDB_PASSWORD"
        
        pg_dump \
            --host="${DB_POSTGRESDB_HOST}" \
            --port="${DB_POSTGRESDB_PORT:-5432}" \
            --username="${DB_POSTGRESDB_USER}" \
            --dbname="${DB_POSTGRESDB_DATABASE}" \
            --schema-only \
            --no-owner \
            --no-privileges \
            > "$backup_path/schema_$TIMESTAMP.sql" || {
            log_error "Database backup failed"
            return 1
        }
        
        log_info "Database schema backed up successfully"
    else
        log_warn "Database credentials not available, skipping database backup"
    fi
}

# Backup knowledge base content
backup_knowledge() {
    local backup_path="$1"
    
    log_info "Backing up knowledge base..."
    
    if [[ -d "$PROJECT_ROOT/knowledge" ]]; then
        cp -r "$PROJECT_ROOT/knowledge" "$backup_path/"
        log_info "Knowledge base backed up successfully"
    else
        log_warn "Knowledge base directory not found"
    fi
}

# Create backup metadata
create_metadata() {
    local backup_path="$1"
    
    cat > "$backup_path/backup_metadata.json" << EOF
{
  "backup_name": "$BACKUP_NAME",
  "timestamp": "$TIMESTAMP",
  "created_at": "$(date -Iseconds)",
  "n8n_version": "$(docker exec n8n-automation n8n --version 2>/dev/null || echo 'unknown')",
  "backup_type": "full",
  "components": [
    "workflows",
    "credentials",
    "database_schema",
    "knowledge_base"
  ],
  "notes": "Automated backup created by backup.sh script"
}
EOF
}

# Cleanup old backups
cleanup_old_backups() {
    local retention_days="${BACKUP_RETENTION_DAYS:-30}"
    
    log_info "Cleaning up backups older than $retention_days days..."
    
    find "$BACKUP_DIR" -type d -name "n8n_backup_*" -mtime "+$retention_days" -exec rm -rf {} + 2>/dev/null || true
}

# Main backup process
main() {
    log_info "Starting n8n infrastructure backup: $BACKUP_NAME"
    
    # Preliminary checks
    check_docker
    
    # Load environment variables
    if [[ -f "$PROJECT_ROOT/.env" ]]; then
        source "$PROJECT_ROOT/.env"
    fi
    
    # Create backup directory
    local backup_path=$(create_backup_dir)
    log_info "Backup directory created: $backup_path"
    
    # Perform backups
    backup_workflows "$backup_path" || log_warn "Workflow backup incomplete"
    backup_credentials "$backup_path" || log_warn "Credentials backup incomplete"
    backup_database "$backup_path" || log_warn "Database backup incomplete"
    backup_knowledge "$backup_path" || log_warn "Knowledge base backup incomplete"
    
    # Create metadata
    create_metadata "$backup_path"
    
    # Cleanup old backups
    cleanup_old_backups
    
    log_info "Backup completed successfully: $backup_path"
    
    # Optional: Create compressed archive
    if command -v tar > /dev/null; then
        local archive_name="$BACKUP_DIR/${BACKUP_NAME}.tar.gz"
        tar -czf "$archive_name" -C "$BACKUP_DIR" "$BACKUP_NAME"
        log_info "Compressed backup created: $archive_name"
    fi
}

# Run main function
main "$@"