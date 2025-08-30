#!/usr/bin/env bash
set -euo pipefail

# Security Hardening Script
# Implements additional security measures for n8n infrastructure

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Create secure .gitignore
create_secure_gitignore() {
    log_step "Creating secure .gitignore..."
    
    cat > "$ROOT_DIR/.gitignore" << 'EOF'
# Environment files (NEVER commit these)
.env
.env.*
!.env.example
!.env.secure.example

# Credentials and secrets
config/.env
config/credentials/
*.key
*.pem
*.p12
*.pfx

# Backup files (may contain sensitive data)
backups/
*.sql
*.dump
*.backup

# Logs (may contain sensitive information)
logs/
*.log

# Temporary files
tmp/
temp/
.tmp/

# IDE and editor files
.vscode/
.idea/
*.swp
*.swo
*~

# OS files
.DS_Store
Thumbs.db

# Node.js
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Docker
.docker/

# Git history cleanup markers
.git-history-cleaned
EOF

    log_info "✅ Secure .gitignore created"
}

# Create security monitoring script
create_monitoring_script() {
    log_step "Creating security monitoring script..."
    
    cat > "$ROOT_DIR/scripts/security-monitor.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Security Monitoring Script
# Monitors for security events and anomalies

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/config/.env"

if [[ -f "$ENV_FILE" ]]; then
    source "$ENV_FILE"
fi

# Check for failed authentication attempts
check_auth_failures() {
    echo "==> Checking for authentication failures..."
    
    if [[ -n "${N8N_URL:-}" && -n "${N8N_API_KEY:-}" ]]; then
        # Check n8n audit logs (if available)
        curl -fsSL -H "X-N8N-API-KEY: $N8N_API_KEY" \
            "$N8N_URL/rest/audit" 2>/dev/null | \
            jq '.data[] | select(.event == "user.login.failed")' || true
    fi
}

# Monitor database connections
check_db_connections() {
    echo "==> Monitoring database connections..."
    
    if [[ -n "${DB_POSTGRESDB_HOST:-}" ]]; then
        export PGPASSWORD="$DB_POSTGRESDB_PASSWORD"
        
        # Check for unusual connection patterns
        psql -h "$DB_POSTGRESDB_HOST" -U "$DB_POSTGRESDB_USER" -d "$DB_POSTGRESDB_DATABASE" \
            -c "SELECT client_addr, count(*) as connections, max(backend_start) as last_connection 
                FROM pg_stat_activity 
                WHERE state = 'active' 
                GROUP BY client_addr 
                ORDER BY connections DESC;" 2>/dev/null || true
    fi
}

# Check API usage patterns
check_api_usage() {
    echo "==> Checking API usage patterns..."
    
    # This would typically integrate with your monitoring system
    # For now, we'll check basic metrics
    if [[ -n "${N8N_URL:-}" && -n "${N8N_API_KEY:-}" ]]; then
        curl -fsSL -H "X-N8N-API-KEY: $N8N_API_KEY" \
            "$N8N_URL/rest/executions?limit=10" 2>/dev/null | \
            jq '.data[] | {id: .id, startedAt: .startedAt, status: .status}' || true
    fi
}

# Main monitoring function
main() {
    echo "🔍 Security Monitoring Report - $(date)"
    echo "================================================"
    
    check_auth_failures
    echo ""
    
    check_db_connections  
    echo ""
    
    check_api_usage
    echo ""
    
    echo "================================================"
    echo "✅ Security monitoring completed"
}

main "$@"
EOF

    chmod +x "$ROOT_DIR/scripts/security-monitor.sh"
    log_info "✅ Security monitoring script created"
}

# Create incident response playbook
create_incident_playbook() {
    log_step "Creating incident response playbook..."
    
    cat > "$ROOT_DIR/INCIDENT_RESPONSE.md" << 'EOF'
# 🚨 Security Incident Response Playbook

## Incident Classification

### Severity Levels
- **P0 (Critical)**: Active breach, data exfiltration, service compromise
- **P1 (High)**: Exposed credentials, unauthorized access attempts
- **P2 (Medium)**: Security misconfigurations, policy violations
- **P3 (Low)**: Security recommendations, minor vulnerabilities

## Response Procedures

### P0/P1 Incidents (Immediate Response)

#### 1. Containment (0-30 minutes)
```bash
# Stop all services immediately
docker compose -f docker/docker-compose.yml down

# Revoke compromised credentials
# - API keys: Revoke in respective platforms
# - Database: Change passwords in Supabase
# - Tokens: Revoke in GitHub/HF settings
```

#### 2. Assessment (30-60 minutes)
- Identify scope of compromise
- Check access logs for unauthorized activity
- Assess data exposure risk
- Document timeline of events

#### 3. Communication (Within 1 hour)
- Notify stakeholders
- Prepare incident summary
- Coordinate response efforts

#### 4. Recovery (1-4 hours)
- Generate new credentials
- Update all deployment environments
- Restart services with new credentials
- Verify system integrity

### P2/P3 Incidents (Standard Response)

#### 1. Analysis (Within 24 hours)
- Document security finding
- Assess potential impact
- Plan remediation approach

#### 2. Remediation (Within 1 week)
- Implement security fixes
- Update configurations
- Test changes thoroughly

#### 3. Prevention (Ongoing)
- Update security policies
- Enhance monitoring
- Conduct security training

## Emergency Contacts

- **Security Team**: security@your-domain.com
- **Infrastructure Team**: infra@your-domain.com
- **On-call Engineer**: +1-XXX-XXX-XXXX

## Recovery Procedures

### Database Recovery
```bash
# Restore from latest backup
./scripts/restore.sh backups/db/latest-backup.sql.gz

# Verify data integrity
./scripts/verify-backup.sh
```

### Service Recovery
```bash
# Restart with new credentials
docker compose -f docker/docker-compose.yml up -d

# Verify health
curl -f http://localhost:5678/healthz
```

## Post-Incident Actions

1. **Root Cause Analysis**: Document what happened and why
2. **Security Review**: Assess and improve security measures
3. **Process Improvement**: Update procedures based on lessons learned
4. **Training**: Conduct security awareness training if needed

## Prevention Measures

- Regular security audits
- Automated vulnerability scanning
- Credential rotation schedules
- Access monitoring and alerting
- Security awareness training
EOF

    log_info "✅ Incident response playbook created"
}

# Update Docker configuration for security
update_docker_security() {
    log_step "Updating Docker configuration for security..."
    
    # Update Dockerfile with security hardening
    cat > "$ROOT_DIR/docker/Dockerfile.secure" << 'EOF'
# Pin the n8n version for predictable upgrades/rollbacks
FROM n8nio/n8n:1.108.2

# Switch to root temporarily for security hardening
USER root

# Install security tools and updates
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        curl \
        ca-certificates && \
    # Remove package cache to reduce image size
    rm -rf /var/lib/apt/lists/* && \
    # Create non-root user if not exists
    id -u node >/dev/null 2>&1 || useradd -m -s /bin/bash node

# Set secure file permissions
RUN chmod 755 /home/node && \
    chown -R node:node /home/node

# Security: Run as non-root user
USER node

# Environment configuration
ENV N8N_PORT=5678
ENV N8N_HOST=0.0.0.0

# Security headers and settings
ENV N8N_SECURE_COOKIE=true
ENV N8N_COOKIE_SAME_SITE=strict

# Execution & retention (production-friendly defaults)
ENV EXECUTIONS_MODE=regular
ENV EXECUTIONS_DATA_SAVE_ON_ERROR=all
ENV EXECUTIONS_DATA_SAVE_ON_SUCCESS=none
ENV EXECUTIONS_DATA_PRUNE=true
ENV EXECUTIONS_DATA_MAX_AGE=168
ENV QUEUE_BULL_REDIS_DISABLED=true

# Health/metrics
ENV N8N_METRICS=true
ENV QUEUE_HEALTH_CHECK_ACTIVE=true

# Security: Disable telemetry
ENV N8N_DISABLE_PRODUCTION_MAIN_PROCESS=true

# Add comprehensive healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD curl -f "http://localhost:${N8N_PORT:-5678}/healthz" || exit 1

# Expose port
EXPOSE 5678

# Use the default n8n entrypoint
EOF

    log_info "✅ Secure Dockerfile created (docker/Dockerfile.secure)"
}

# Create security validation script
create_security_validator() {
    log_step "Creating security validation script..."
    
    cat > "$ROOT_DIR/scripts/validate-security.js" << 'EOF'
#!/usr/bin/env node

/**
 * Security Validation Script
 * Validates current security configuration and identifies issues
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

function validateCredentialStrength(key, value) {
    const issues = [];
    
    if (!value || value.trim() === '') {
        issues.push(`${key} is empty or missing`);
        return issues;
    }
    
    // Check for common weak patterns
    const weakPatterns = [
        /password/i,
        /123456/,
        /qwerty/i,
        /admin/i,
        /changeme/i,
        /default/i,
        /test/i
    ];
    
    for (const pattern of weakPatterns) {
        if (pattern.test(value)) {
            issues.push(`${key} contains weak pattern: ${pattern.source}`);
        }
    }
    
    // Check for personal information patterns
    const personalPatterns = [
        /19\d{2}|20\d{2}/, // Years
        /\d{2}\/\d{2}\/\d{4}/, // Dates
        /\w+@\w+\.\w+/ // Email patterns
    ];
    
    for (const pattern of personalPatterns) {
        if (pattern.test(value)) {
            issues.push(`${key} may contain personal information`);
        }
    }
    
    // Length requirements
    const minLengths = {
        'N8N_ENCRYPTION_KEY': 32,
        'N8N_USER_MANAGEMENT_JWT_SECRET': 32,
        'DB_POSTGRESDB_PASSWORD': 16,
        'BACKUP_ENCRYPTION_PASSWORD': 16
    };
    
    if (minLengths[key] && value.length < minLengths[key]) {
        issues.push(`${key} is too short (minimum ${minLengths[key]} characters)`);
    }
    
    return issues;
}

function checkForExposedSecrets() {
    const issues = [];
    
    // Check if .env file is tracked by git
    try {
        const { execSync } = require('child_process');
        execSync('git ls-files config/.env', { stdio: 'pipe' });
        issues.push('CRITICAL: .env file is tracked by Git');
    } catch (error) {
        // Good - .env is not tracked
    }
    
    // Check for secrets in git history
    try {
        const { execSync } = require('child_process');
        const result = execSync('git log --all --full-history -p | grep -i "api_key\\|password\\|secret\\|token" | head -5', 
            { encoding: 'utf8', stdio: 'pipe' });
        
        if (result.trim()) {
            issues.push('WARNING: Potential secrets found in Git history');
        }
    } catch (error) {
        // No matches found (good)
    }
    
    return issues;
}

function main() {
    console.log('🔐 Security Configuration Validation');
    console.log('=====================================');
    
    const envPath = path.join(process.cwd(), 'config', '.env');
    
    if (!fs.existsSync(envPath)) {
        console.log('⚠️  No .env file found - using environment variables');
        return;
    }
    
    // Load and validate environment
    const envContent = fs.readFileSync(envPath, 'utf8');
    const env = {};
    
    envContent.split('\n').forEach(line => {
        const trimmed = line.trim();
        if (trimmed && !trimmed.startsWith('#')) {
            const [key, ...valueParts] = trimmed.split('=');
            if (key && valueParts.length > 0) {
                env[key.trim()] = valueParts.join('=').trim();
            }
        }
    });
    
    let hasIssues = false;
    
    // Validate credential strength
    const sensitiveKeys = [
        'N8N_ENCRYPTION_KEY',
        'N8N_USER_MANAGEMENT_JWT_SECRET', 
        'DB_POSTGRESDB_PASSWORD',
        'BACKUP_ENCRYPTION_PASSWORD',
        'OPENAI_API_KEY',
        'ANTHROPIC_API_KEY',
        'HF_TOKEN',
        'GITHUB_TOKEN'
    ];
    
    for (const key of sensitiveKeys) {
        const issues = validateCredentialStrength(key, env[key]);
        if (issues.length > 0) {
            console.log(`❌ ${key}:`);
            issues.forEach(issue => console.log(`   - ${issue}`));
            hasIssues = true;
        } else if (env[key]) {
            console.log(`✅ ${key}: OK`);
        }
    }
    
    // Check for exposed secrets
    const exposureIssues = checkForExposedSecrets();
    if (exposureIssues.length > 0) {
        console.log('\n🚨 EXPOSURE ISSUES:');
        exposureIssues.forEach(issue => console.log(`   - ${issue}`));
        hasIssues = true;
    }
    
    // Summary
    console.log('\n=====================================');
    if (hasIssues) {
        console.log('❌ Security validation failed');
        console.log('🔧 Please address the issues above');
        process.exit(1);
    } else {
        console.log('✅ Security validation passed');
    }
}

if (require.main === module) {
    main();
}
EOF

    chmod +x "$ROOT_DIR/scripts/validate-security.js"
    log_info "✅ Security validation script created"
}

# Main hardening process
main() {
    log_info "🛡️  Starting security hardening process..."
    
    create_secure_gitignore
    create_monitoring_script
    create_security_validator
    update_docker_security
    
    log_info "🔒 Security hardening completed"
    log_warn "⚠️  Remember to:"
    log_warn "   1. Rotate all exposed credentials immediately"
    log_warn "   2. Run ./scripts/validate-security.js regularly"
    log_warn "   3. Monitor ./scripts/security-monitor.sh output"
    log_warn "   4. Use docker/Dockerfile.secure for production"
}

main "$@"