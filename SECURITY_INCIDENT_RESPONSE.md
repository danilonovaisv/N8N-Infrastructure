# 🚨 SECURITY INCIDENT RESPONSE CHECKLIST

## IMMEDIATE ACTIONS (Complete within 1 hour)

### 1. Revoke All Exposed Credentials
- [ ] **OpenAI**: Go to https://platform.openai.com/api-keys → Delete exposed key
- [ ] **Anthropic**: Go to https://console.anthropic.com → Revoke API key
- [ ] **Hugging Face**: Go to https://huggingface.co/settings/tokens → Delete token
- [ ] **GitHub**: Go to https://github.com/settings/tokens → Delete token
- [ ] **ChromaDB**: Contact support or revoke via dashboard

### 2. Database Security
- [ ] **Supabase**: Change database password immediately
- [ ] **Review connections**: Check recent database connections for unauthorized access
- [ ] **Enable audit logging**: Turn on connection and query logging

### 3. N8N Security
- [ ] **Stop n8n instance** to prevent further credential usage
- [ ] **Generate new encryption key**: `openssl rand -hex 32`
- [ ] **Generate new JWT secret**: `openssl rand -hex 32`
- [ ] **Clear credential cache** in n8n

### 4. Infrastructure Security
- [ ] **Rotate backup encryption password**
- [ ] **Check Hugging Face Space logs** for unauthorized access
- [ ] **Review GitHub repository access logs**

## VERIFICATION STEPS

### 1. Confirm Credential Revocation
```bash
# Test if old tokens still work (should fail)
curl -H "Authorization: Bearer OLD_TOKEN" https://api.openai.com/v1/models
curl -H "Authorization: Bearer OLD_HF_TOKEN" https://huggingface.co/api/whoami
```

### 2. Database Access Test
```bash
# Verify old password no longer works
psql -h aws-1-sa-east-1.pooler.supabase.com -U postgres.vkgwjmvekrlrjybbmtks -d postgres
# Should fail with authentication error
```

### 3. Service Functionality
- [ ] Verify n8n starts with new credentials
- [ ] Test workflow execution
- [ ] Confirm database connectivity
- [ ] Validate API integrations

## INCIDENT DOCUMENTATION

**Incident ID:** SEC-$(date +%Y%m%d-%H%M%S)
**Discovery Date:** $(date -Iseconds)
**Severity:** Critical
**Status:** In Progress

**Timeline:**
- Discovery: Configuration file with exposed credentials identified
- Response: Immediate credential revocation initiated
- Resolution: [To be completed]

**Affected Systems:**
- n8n automation platform
- Supabase database
- AI service integrations (OpenAI, Anthropic)
- Hugging Face Space deployment
- GitHub repository access

**Next Steps:**
1. Complete credential rotation
2. Implement secure credential management
3. Conduct security review of all systems
4. Update security policies and procedures