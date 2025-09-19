# Migration Guide: Hugging Face + Supabase → claw.cloud

This document explains the migration from Hugging Face and Supabase to claw.cloud for your N8N infrastructure.

## 🔄 What Changed

### Before (Old Configuration)
- **Hosting**: Hugging Face Spaces
- **Database**: Supabase PostgreSQL with pooler connection
- **Authentication**: HF_TOKEN for deployments
- **URLs**: `*.hf.space` domains

### After (New Configuration) 
- **Hosting**: claw.cloud
- **Database**: PostgreSQL directly on claw.cloud Kubernetes
- **Authentication**: CLAW_TOKEN for deployments  
- **URLs**: `*.claw.cloud` domains

## 📁 Files Modified

### 1. Environment Configuration
- **New**: `.env.claw` - Complete claw.cloud configuration
- **Updated**: `config/.env.example` - Template with claw.cloud settings

### 2. Docker Configuration
- **Updated**: `docker-compose.yml` - New database connection parameters

### 3. Kubernetes Configuration  
- **Updated**: `bridge/base/n8n-deployment.yaml` - claw.cloud URLs and database settings

### 4. CI/CD Configuration
- **Updated**: `.github/workflows/docker-publish.yml` - Uses CLAW_TOKEN
- **Updated**: `.github/workflows/sync-knowledge.yml` - Removed Supabase dependencies

## 🗄️ Database Migration

### Old Configuration (Supabase)
```env
DB_TYPE=postgresdb
DB_POSTGRESDB_CONNECTION_STRING=postgresql://postgres.vkgwjmvekrlrjybbmtks:***@aws-1-sa-east-1.pooler.supabase.com:6543/postgres?pgbouncer=true&sslmode=verify-full
DB_POSTGRESDB_SSL=true
```

### New Configuration (claw.cloud)
```env
DB_TYPE=postgresql
DB_POSTGRESDB_HOST=n8n-database-postgresql.ns-t3rlqt6e.svc
DB_POSTGRESDB_PORT=5432
DB_POSTGRESDB_CONNECTION=postgresql://postgres:rwdh7jbk@n8n-database-postgresql.ns-t3rlqt6e.svc:5432
DB_POSTGRESDB_USER=postgres
DB_POSTGRESDB_DATABASE=pn8n-database-postgresql-0
DB_POSTGRESDB_PASSWORD=rwdh7jbk
```

## 🚀 Deployment Steps

### 1. Update Environment Variables
Copy the configuration from `.env.claw` and set these in your claw.cloud deployment:

```bash
# Replace your-n8n-app with your actual app name
N8N_HOST=your-n8n-app.claw.cloud
WEBHOOK_URL=https://your-n8n-app.claw.cloud/
ALLOWED_ORIGINS=https://your-n8n-app.claw.cloud

# Database (use provided values)
DB_TYPE=postgresql
DB_POSTGRESDB_HOST=n8n-database-postgresql.ns-t3rlqt6e.svc
DB_POSTGRESDB_PORT=5432
DB_POSTGRESDB_USER=postgres
DB_POSTGRESDB_PASSWORD=rwdh7jbk
DB_POSTGRESDB_DATABASE=pn8n-database-postgresql-0

# Authentication
CLAW_TOKEN=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
```

### 2. Update GitHub Secrets
Remove old secrets and add new ones:

**Remove these secrets:**
- `HF_TOKEN`
- `SUPABASE_URL` 
- `SUPABASE_SERVICE_ROLE_KEY`

**Add/Update these secrets:**
- `CLAW_TOKEN=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`

### 3. Deploy to claw.cloud
1. Push your changes to your repository
2. Connect your repository to claw.cloud
3. Configure the environment variables in claw.cloud dashboard
4. Deploy the application

## 🔧 Key Configuration Changes

### URLs and Hostnames
- **Old**: `danilonovais-n8n-dan.hf.space`
- **New**: `your-n8n-app.claw.cloud`

### Database Connection  
- **Removed**: SSL pooler configuration, Supabase-specific settings
- **Added**: Direct PostgreSQL connection to Kubernetes service

### Authentication
- **Removed**: `HF_TOKEN`, `HF_SPACE_NAME`
- **Added**: `CLAW_TOKEN`

## ⚠️ Important Notes

1. **Database Migration**: You'll need to migrate your data from Supabase to the new PostgreSQL instance on claw.cloud
2. **DNS Updates**: Update any external integrations pointing to your old `.hf.space` URLs
3. **SSL**: The new setup doesn't require SSL configuration for the database connection
4. **Backup**: Make sure to backup your Supabase data before migration

## 🔍 Verification

After deployment, verify these components work:
- [ ] N8N web interface accessible at `https://your-n8n-app.claw.cloud`
- [ ] Database connections working (check N8N logs)
- [ ] Webhooks receiving requests at new URLs
- [ ] GitHub Actions deploying successfully with CLAW_TOKEN
- [ ] All workflows functioning correctly

## 📞 Support

If you encounter issues during migration:
1. Check claw.cloud documentation
2. Verify all environment variables are set correctly
3. Check application logs for database connection errors
4. Ensure CLAW_TOKEN has proper permissions

---

**Migration completed on**: $(date)  
**Configuration files updated**: `.env.claw`, `docker-compose.yml`, Kubernetes manifests, GitHub Actions