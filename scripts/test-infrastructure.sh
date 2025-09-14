#!/bin/bash

# Infrastructure Testing Script
# Tests all components of the n8n infrastructure
# Usage: ./test-infrastructure.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_test() { echo -e "${BLUE}[TEST]${NC} $1"; }

# Test results tracking
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    ((TESTS_TOTAL++))
    log_test "Running: $test_name"
    echo "  Executing: $test_command"
    
    if eval "$test_command"; then
        echo "  ✅ PASSED"
        ((TESTS_PASSED++))
        return 0
    else
        echo "  ❌ FAILED"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Load environment
if [[ -f "$PROJECT_ROOT/.env" ]]; then
    source "$PROJECT_ROOT/.env"
fi

# Test Docker configuration
test_docker() {
    log_info "Testing Docker configuration..."
    
    run_test "Docker daemon accessible" "sudo docker --version"
    run_test "Docker Compose available" "sudo docker compose version"
    run_test "Dockerfile syntax" "sudo docker build -f docker/Dockerfile -t n8n-test-build ."
    run_test "Docker Compose syntax" "sudo docker compose -f docker/docker-compose.yml config"
}

# Test environment configuration
test_environment() {
    log_info "Testing environment configuration..."
    
    run_test "Environment example exists" "[[ -f config/.env.example ]]"
    run_test "Required directories exist" "[[ -d workflows && -d scripts ]]"
    
    if [[ -f .env ]]; then
        run_test "Environment file loaded" "[[ -n \${N8N_ENCRYPTION_KEY:-} ]]"
        run_test "Database config present" "[[ -n \${DB_POSTGRESDB_HOST:-} ]]"
    else
        log_warn "No .env file found - using example for testing"
    fi
}

# Test scripts
test_scripts() {
    log_info "Testing infrastructure scripts..."
    
    run_test "Backup script executable" "[[ -x scripts/backup.sh ]]"
    run_test "Restore script executable" "[[ -x scripts/restore.sh ]]" 
    run_test "Sync script syntax" "bash -n scripts/sync-knowledge.sh"
    run_test "Backup script syntax" "bash -n scripts/backup.sh"
    run_test "Restore script syntax" "bash -n scripts/restore.sh"
}

# Test GitHub Actions
test_github_actions() {
    log_info "Testing GitHub Actions workflows..."
    
    run_test "Deploy workflow exists" "[[ -f .github/workflows/deploy-to-hf.yml ]]"
    run_test "Backup workflow exists" "[[ -f .github/workflows/backup-workflows.yml ]]"
    run_test "Sync workflow exists" "[[ -f .github/workflows/sync-knowledge.yml ]]"
    
    # Validate workflow syntax (basic YAML check)
    if command -v python3 > /dev/null; then
        run_test "Deploy workflow syntax" "python3 -c \"import yaml; yaml.safe_load(open('.github/workflows/deploy-to-hf.yml'))\""
        run_test "Backup workflow syntax" "python3 -c \"import yaml; yaml.safe_load(open('.github/workflows/backup-workflows.yml'))\""
        run_test "Sync workflow syntax" "python3 -c \"import yaml; yaml.safe_load(open('.github/workflows/sync-knowledge.yml'))\""
    fi
}

# Test database connectivity
test_database() {
    log_info "Testing database connectivity..."
    
    if [[ -n "${DB_POSTGRESDB_HOST:-}" && -n "${DB_POSTGRESDB_PASSWORD:-}" ]]; then
        export PGPASSWORD="$DB_POSTGRESDB_PASSWORD"
        
        run_test "Database connection" "pg_isready -h '$DB_POSTGRESDB_HOST' -p '${DB_POSTGRESDB_PORT:-5432}' -U '$DB_POSTGRESDB_USER'"
        run_test "Database access" "psql -h '$DB_POSTGRESDB_HOST' -p '${DB_POSTGRESDB_PORT:-5432}' -U '$DB_POSTGRESDB_USER' -d '$DB_POSTGRESDB_DATABASE' -c 'SELECT 1;'"
        run_test "pgvector extension" "psql -h '$DB_POSTGRESDB_HOST' -p '${DB_POSTGRESDB_PORT:-5432}' -U '$DB_POSTGRESDB_USER' -d '$DB_POSTGRESDB_DATABASE' -c 'SELECT * FROM pg_extension WHERE extname = \\'vector\\';'"
    else
        log_warn "Database credentials not available - skipping connectivity tests"
    fi
}

# Integration tests
test_integration() {
    log_info "Running integration tests..."
    
    # Test if we can start services locally
    if run_test "Start services locally" "sudo docker compose -f docker/docker-compose.yml up -d --build"; then
        sleep 30
        
        run_test "n8n health endpoint" "curl -f http://localhost:5678/healthz"
        
        # Cleanup
        sudo docker compose -f docker/docker-compose.yml down > /dev/null 2>&1
    else
        log_error "Failed to start services - skipping integration tests"
    fi
}

# Main test execution
main() {
    log_info "🧪 Starting n8n Infrastructure Test Suite"
    echo "================================================"
    
    cd "$PROJECT_ROOT"
    
    # Run all test categories
    test_docker
    test_environment  
    test_scripts
    test_github_actions
    test_database
    
    # Skip integration tests if Docker unavailable
    if sudo docker --version > /dev/null 2>&1; then
        test_integration
    else
        log_warn "Docker not available - skipping integration tests"
    fi
    
    # Test summary
    echo ""
    echo "================================================"
    log_info "🎯 Test Results Summary"
    echo "   Total Tests: $TESTS_TOTAL"
    echo "   Passed: $TESTS_PASSED"
    echo "   Failed: $TESTS_FAILED"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "   Status: ✅ ALL TESTS PASSED"
        exit 0
    else
        echo "   Status: ❌ SOME TESTS FAILED"
        exit 1
    fi
}

main "$@"