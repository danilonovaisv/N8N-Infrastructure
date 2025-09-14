#!/usr/bin/env bash
set -euo pipefail

# Secret Rotation Script
# Generates new secure credentials and provides rotation checklist

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Generate secure random strings
generate_key() {
    local length=${1:-32}
    openssl rand -hex "$length"
}

generate_password() {
    local length=${1:-24}
    LC_ALL=C tr -dc 'A-Za-z0-9!@#$%^&*()_+-=' </dev/urandom | head -c "$length"
}

main() {
    log_info "🔐 Starting credential rotation process..."
    echo ""
    
    log_step "Generating new secure credentials..."
    
    # Generate new keys
    NEW_ENCRYPTION_KEY=$(generate_key 32)
    NEW_JWT_SECRET=$(generate_key 32)
    NEW_CSRF_SECRET=$(generate_key 16)
    NEW_DB_PASSWORD=$(generate_password 24)
    NEW_BACKUP_PASSWORD=$(generate_password 24)
    NEW_ADMIN_PASSWORD=$(generate_password 16)
    
    echo "# ===== NEW SECURE CREDENTIALS ====="
    echo "# Generated on: $(date -Iseconds)"
    echo "# IMPORTANT: Update these in your deployment environment"
    echo ""
    echo "N8N_ENCRYPTION_KEY=$NEW_ENCRYPTION_KEY"
    echo "N8N_USER_MANAGEMENT_JWT_SECRET=$NEW_JWT_SECRET"
    echo "CSRF_SECRET=$NEW_CSRF_SECRET"
    echo "DB_POSTGRESDB_PASSWORD=$NEW_DB_PASSWORD"
    echo "BACKUP_ENCRYPTION_PASSWORD=$NEW_BACKUP_PASSWORD"
    echo "N8N_BASIC_AUTH_PASSWORD=$NEW_ADMIN_PASSWORD"
    echo ""
    
    log_warn "⚠️  CRITICAL ROTATION CHECKLIST:"
    echo ""
    echo "🔴 IMMEDIATE (within 1 hour):"
    echo "  1. Revoke exposed API keys:"
    echo "     - OpenAI: https://platform.openai.com/api-keys"
    echo "     - Anthropic: https://console.anthropic.com"
    echo "     - Hugging Face: https://huggingface.co/settings/tokens"
    echo "     - GitHub: https://github.com/settings/tokens"
    echo "     - ChromaDB: Contact support or dashboard"
    echo ""
    echo "  2. Update Supabase database password:"
    echo "     - Go to Supabase dashboard → Settings → Database"
    echo "     - Change password to: $NEW_DB_PASSWORD"
    echo ""
    echo "  3. Update Hugging Face Space secrets:"
    echo "     - Go to your Space → Settings → Repository secrets"
    echo "     - Update all environment variables with new values"
    echo ""
    
    echo "🟡 WITHIN 24 HOURS:"
    echo "  4. Generate new API keys:"
    echo "     - Create new OpenAI API key with usage limits"
    echo "     - Create new Anthropic API key"
    echo "     - Create new GitHub token with minimal required scopes"
    echo "     - Create new Hugging Face token"
    echo ""
    echo "  5. Update GitHub repository secrets:"
    echo "     - Go to repository → Settings → Secrets and variables → Actions"
    echo "     - Update all secrets with new values"
    echo ""
    echo "  6. Restart n8n with new encryption key:"
    echo "     - Stop n8n instance"
    echo "     - Update N8N_ENCRYPTION_KEY"
    echo "     - Re-enter all stored credentials in n8n"
    echo "     - Start n8n instance"
    echo ""
    
    echo "🟢 WITHIN 1 WEEK:"
    echo "  7. Security hardening:"
    echo "     - Enable basic authentication"
    echo "     - Implement IP allowlisting if possible"
    echo "     - Set up monitoring and alerting"
    echo "     - Conduct security review of all workflows"
    echo ""
    
    log_error "❌ DO NOT USE THE EXPOSED CONFIGURATION FILE"
    log_error "❌ ASSUME ALL EXPOSED CREDENTIALS ARE COMPROMISED"
    log_info "✅ Save this output securely and follow the checklist"
}

main "$@"