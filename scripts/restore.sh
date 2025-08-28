#!/bin/bash

# n8n Infrastructure Restore Script
# Restores workflows, credentials, and configurations from backup
# Usage: ./restore.sh <backup-name>

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_ROOT/workflows/backup"

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

# Validate backup name argument
if [[ $# -eq 0 ]]; then
    log_error "Usage: $0 <backup-name>"
    log_info "Available backups:"
    ls -1 "$BACKUP_DIR" | grep -E "^n8n_backup_" | head -10
    exit 1
fi

BACKUP_NAME="$1"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

# Check if backup exists
if [[ ! -d "$BACKUP_PATH" ]]; then
    # Try with .tar.gz extension
    if [[ -f "$BACKUP_DIR/$BACKUP_NAME.tar.gz" ]]; then
        log_info "Found compressed backup, extracting..."
        tar -xzf "$BACKUP_DIR/$BACKUP_NAME.tar.gz" -C "$BACKUP_DIR"
    else
        log_error "Backup not found: $BACKUP_NAME"
        exit 1
    fi
fi

# Verify backup integrity
verify_backup() {
    local metadata_file="$BACKUP_PATH/backup_metadata.json"
    
    if [[ ! -f "$metadata_file" ]]; then
        log_warn "Backup metadata not found, proceeding with caution"
        return 0
    fi
    
    log_info "Backup verification:"
    cat "$metadata_file" | jq -r '.backup_name, .created_at, .backup_type'
}

# Restore workflows
restore_workflows() {
    local container_name="n8n-automation"
    
    log_info "Restoring workflows..."
    
    if ! docker ps --format '{{.Names}}' | grep -q "^$container_name$"; then
        log_error "n8n container not running. Start the container first."
        return 1
    fi
    
    # Find workflow backup file
    local workflow_file=$(find "$BACKUP_PATH" -name "workflows_*.json" | head -1)
    
    if [[ -n "$workflow_file" ]]; then
        # Copy workflow file to container
        docker cp "$workflow_file" "$container_name:/tmp/workflows_restore.json"
        
        # Import workflows
        docker exec "$container_name" n8n import:workflow --input="/tmp/workflows_restore.json" || {
            log_error "Failed to import workflows"
            return 1
        }
        
        log_info "Workflows restored successfully"
    else
        log_warn "No workflow backup file found"
    fi
}

# Restore credentials
restore_credentials() {
    local container_name="n8n-automation"
    
    log_info "Restoring credentials..."
    
    if [[ -d "$BACKUP_PATH/credentials" ]]; then
        docker cp "$BACKUP_PATH/credentials/." "$container_name:/home/node/.n8n/credentials/"
        log_info "Credentials restored successfully"
    else
        log_warn "No credentials backup found"
    fi
}

# Restore database (schema only, data should be preserved)
restore_database() {
    log_info "Restoring database schema..."
    
    local schema_file=$(find "$BACKUP_PATH" -name "schema_*.sql" | head -1)
    
    if [[ -n "$schema_file" && -n "${DB_POSTGRESDB_PASSWORD:-}" ]]; then
        export PGPASSWORD="$DB_POSTGRESDB_PASSWORD"
        
        log_warn "This will update database schema. Proceed? (y/N)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            psql \
                --host="${DB_POSTGRESDB_HOST}" \
                --port="${DB_POSTGRESDB_PORT:-5432}" \
                --username="${DB_POSTGRESDB_USER}" \
                --dbname="${DB_POSTGRESDB_DATABASE}" \
                --file="$schema_file" || {
                log_error "Database restore failed"
                return 1
            }
            log_info "Database schema restored successfully"
        else
            log_info "Database restore skipped"
        fi
    else
        log_warn "No database backup found or credentials missing"
    fi
}

# Restart services after restore
restart_services() {
    log_info "Restarting n8n services..."
    
    docker-compose -f "$PROJECT_ROOT/docker/docker-compose.yml" restart n8n
    
    # Wait for service to be ready
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -f http://localhost:7860/healthz > /dev/null 2>&1; then
            log_info "n8n service is ready"
            break
        fi
        
        log_info "Waiting for n8n to start... ($attempt/$max_attempts)"
        sleep 10
        ((attempt++))
    done
    
    if [[ $attempt -gt $max_attempts ]]; then
        log_error "n8n failed to start after restore"
        return 1
    fi
}

# Main restore process
main() {
    log_info "Starting n8n infrastructure restore: $BACKUP_NAME"
    
    # Load environment variables
    if [[ -f "$PROJECT_ROOT/.env" ]]; then
        source "$PROJECT_ROOT/.env"
    fi
    
    # Verify backup
    verify_backup
    
    # Confirm restore operation
    log_warn "This will restore n8n configuration from backup: $BACKUP_NAME"
    log_warn "Current workflows and credentials may be overwritten. Continue? (y/N)"
    read -r response
    
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_info "Restore operation cancelled"
        exit 0
    fi
    
    # Perform restore operations
    restore_workflows || log_warn "Workflow restore incomplete"
    restore_credentials || log_warn "Credentials restore incomplete"
    restore_database || log_warn "Database restore incomplete"
    
    # Restart services
    restart_services
    
    log_info "Restore completed successfully"
    log_info "Access your n8n instance at: ${WEBHOOK_URL:-http://localhost:7860}"
}

# Run main function
main "$@"