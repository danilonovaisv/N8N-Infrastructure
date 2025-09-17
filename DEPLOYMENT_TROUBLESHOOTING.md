# 🔧 Deployment Troubleshooting Guide

## Common Issues and Solutions

### 1. Permission Errors (Fixed ✅)

**Error**: `Permission denied: '/app/static/index.html'` or `unable to open database file`

**Solution**: Fixed in latest version with:
- Directory creation as `appuser` instead of root
- Proper ownership management in Docker
- Fallback to `/tmp` directories for critical files
- Auto-detection of production vs local environments

### 2. Database Connection Issues

**Error**: `unable to open database file` or PostgreSQL connection failures

**Solutions**:
1. **Automatic Fallback**: App now automatically falls back from PostgreSQL → SQLite → Temp Database
2. **Environment Detection**: Automatically uses PostgreSQL in production (Docker/HF Spaces)
3. **Manual Override**: Set `DB_TYPE=sqlite` to force SQLite usage

### 3. Hugging Face Space Configuration

**Required Secrets in HF Space**:
```bash
DB_POSTGRESDB_PASSWORD=An@10011982@@
```

**Required GitHub Secrets**:
```bash
HF_TOKEN=your_hugging_face_write_token
DB_POSTGRESDB_PASSWORD=An@10011982@@
```

### 4. Environment Variables

The app loads configuration in this order:
1. Environment variables (highest priority)
2. `.env.hf` file 
3. Auto-detected defaults

**Key Variables**:
```bash
# Database
DB_TYPE=postgresdb  # Auto-detected in production
DB_POSTGRESDB_HOST=aws-1-sa-east-1.pooler.supabase.com
DB_POSTGRESDB_PORT=6543
DB_POSTGRESDB_DATABASE=postgres
DB_POSTGRESDB_USER=postgres.vkgwjmvekrlrjybbmtks
DB_POSTGRESDB_SSL=true

# Application
HOST=0.0.0.0
PORT=7860
```

### 5. Startup Flow

The application follows this startup sequence:
1. **Environment Setup**: Load `.env.hf` and detect production/local
2. **Database Detection**: Try PostgreSQL → SQLite → Temp fallback
3. **Directory Creation**: Create needed directories with proper permissions
4. **Static Files**: Create HTML interface (fallback to API-served content)
5. **Workflow Indexing**: Index available workflow files
6. **API Server Start**: Start FastAPI server on port 7860

### 6. Health Check Endpoints

**Local Testing**:
```bash
curl http://localhost:7860/health
curl http://localhost:7860/api/stats
```

**Production Testing**:
```bash
curl https://danilonovais-n8n-dan.hf.space/health
curl https://danilonovais-n8n-dan.hf.space/api/stats
```

### 7. Logs Analysis

**What to look for**:
- ✅ `Auto-detected production environment - using PostgreSQL`
- ✅ `Database ready: X workflows available`
- ✅ `Directory created/verified: database`
- ✅ `Server starting on 0.0.0.0:7860`

**Warning signs**:
- ⚠️ `Could not create directory - using system temp`
- ⚠️ `PostgreSQL failed, falling back to SQLite`
- ❌ `Database setup error`

### 8. Manual Deployment

If automatic deployment fails:

```bash
# 1. Check GitHub Actions logs
gh run list --workflow="deploy-to-hf.yml"

# 2. Trigger manual deployment
gh workflow run deploy-to-hf.yml

# 3. Check HF Space logs
# Visit: https://huggingface.co/spaces/danilonovais/n8n-dan/logs
```

### 9. Database Verification

**PostgreSQL Connection Test**:
The app will automatically test database connectivity and provide detailed logs about connection status.

**SQLite Fallback**:
If PostgreSQL fails, the app creates a local SQLite database and indexes available workflow files.

### 10. Performance Optimization

**Expected Performance**:
- Database initialization: < 30 seconds
- API response time: < 100ms for most queries
- Workflow indexing: 1-2 minutes for 2000+ workflows
- Memory usage: < 500MB

### 11. Emergency Recovery

If the deployment completely fails:

1. **Check Space Status**: Verify HF Space exists and is configured correctly
2. **Reset Environment**: Clear all HF Space secrets and re-add them
3. **Force Rebuild**: Delete and recreate the HF Space if necessary
4. **Local Testing**: Use `python3 test_app.py` to verify functionality

### 12. Success Indicators

**Deployment Successful When**:
- ✅ HF Space shows "Running" status
- ✅ `/health` endpoint returns HTTP 200
- ✅ `/api/stats` shows workflow count > 0
- ✅ `/docs` shows Swagger API documentation
- ✅ Database connections working (check logs)

### 13. Contact & Support

**Logs to Check**:
1. GitHub Actions workflow logs
2. Hugging Face Spaces logs (in Space settings)
3. Application logs (shown in HF Space interface)

**Key Files**:
- `app.py` - Main application entry point
- `api_server.py` - FastAPI server
- `workflow_db.py` - Database management
- `.env.hf` - Production configuration
- `Dockerfile` - Container configuration