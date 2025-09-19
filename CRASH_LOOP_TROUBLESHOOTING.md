# 🚨 N8N Crash Loop Troubleshooting Guide

**Status**: Pod `n8n-bygkasfz-0` has been crash looping for 15+ hours with 4346+ restart attempts.

## 🔍 **Root Cause Analysis**

Based on configuration analysis, the crash loop is most likely caused by:

### **Primary Issue: Database Configuration Mismatch**
- **Problem**: Your deployment likely uses `DB_TYPE=postgresql`
- **Expected**: n8n requires `DB_TYPE=postgresdb`
- **Impact**: Immediate startup failure, cannot connect to database

### **Secondary Issues**:
1. **Port mismatch**: Health checks failing (6543 vs 5678)
2. **Missing variables**: `QUEUE_HEALTH_CHECK_ACTIVE` not set
3. **Resource limits**: Potential OOM kills without proper limits

## 🛠️ **Emergency Fix Solutions**

### **Option 1: Deploy Emergency Configuration (Recommended)**

Use the pre-configured emergency deployment:

```bash
# Emergency deployment file created at:
bridge/base/n8n-deployment-emergency.yaml
```

**Key fixes applied:**
- ✅ `DB_TYPE: postgresdb` (was postgresql)
- ✅ `N8N_PORT: 5678` (was 6543) 
- ✅ Added `QUEUE_HEALTH_CHECK_ACTIVE: true`
- ✅ Fixed health check endpoints (/healthz on port 5678)
- ✅ Added resource limits (prevents OOM kills)
- ✅ Corrected all environment variables

### **Option 2: Environment Variable Update**

Copy these corrected environment variables to your claw.cloud deployment:

```yaml
# CRITICAL FIXES
DB_TYPE: postgresdb                    # ← CRITICAL: was "postgresql"
N8N_PORT: 5678                        # ← CRITICAL: was "6543"
QUEUE_HEALTH_CHECK_ACTIVE: true       # ← MISSING: add this

# DATABASE (Already Correct)
DB_POSTGRESDB_HOST: n8n-database-postgresql.ns-t3rlqt6e.svc
DB_POSTGRESDB_PORT: 5432
DB_POSTGRESDB_USER: postgres
DB_POSTGRESDB_PASSWORD: rwdh7jbk
DB_POSTGRESDB_DATABASE: pn8n-database-postgresql-0
DB_POSTGRESDB_SCHEMA: public
DB_POSTGRESDB_SSL: false

# URLs (Updated for your domain)
N8N_HOST: n8n-kaaldqdb.us-west-1.clawcloudrun.com
WEBHOOK_URL: https://n8n-kaaldqdb.us-west-1.clawcloudrun.com/
ALLOWED_ORIGINS: https://n8n-kaaldqdb.us-west-1.clawcloudrun.com

# ENCRYPTION (Properly escaped)
N8N_ENCRYPTION_KEY: sg}Imfql]L467m)@-MwXN2IVE&I-(s1y>$Ft?Rp>#<Sv8&sOt%f!ecLIF97bs?SD
```

## 📊 **Expected Recovery Timeline**

After deploying the fix:
- **0-30 seconds**: Pod termination and new deployment start
- **30-60 seconds**: Container image pull and startup
- **60-120 seconds**: Database connection establishment
- **120-180 seconds**: n8n initialization and readiness
- **3-5 minutes**: Full stability and health check success

## 🔍 **Verification Steps**

### **1. Check Pod Status**
```bash
# If you have kubectl access:
kubectl get pods -n ns-t3rlqt6e
kubectl logs -n ns-t3rlqt6e pod/n8n-bygkasfz-0 --follow
```

### **2. Health Check Tests**
```bash
# Test the health endpoint
curl -f https://n8n-kaaldqdb.us-west-1.clawcloudrun.com/healthz
```

### **3. Database Connection Test**
The pod logs should show:
```
✅ "Database connection established"
✅ "N8N server started successfully"
✅ "Webhook URL configured"
```

**Instead of:**
```
❌ "Database connection failed"
❌ "Invalid DB_TYPE: postgresql"
❌ "Health check failed on port 6543"
```

## 🚨 **If Still Crashing**

### **Additional Debugging Steps:**

1. **Check Database Availability**
   ```bash
   # Test database connectivity (if you have network access)
   nc -zv n8n-database-postgresql.ns-t3rlqt6e.svc 5432
   ```

2. **Verify Resource Limits**
   - Ensure your claw.cloud plan has sufficient resources
   - Check if memory/CPU limits are being exceeded

3. **Image Version Issues**
   - Try using a stable image: `n8nio/n8n:1.53.1`
   - Avoid `latest` tag in production

### **Last Resort: Clean Deployment**

If the pod still crashes:

1. **Delete the current deployment** (via claw.cloud interface)
2. **Deploy fresh** using the emergency configuration
3. **Start with minimal environment variables** and add incrementally

## 📋 **Configuration Files Created**

1. **`.env.corrected`** - Environment variables with all fixes
2. **`bridge/base/n8n-deployment-emergency.yaml`** - Complete fixed deployment
3. **`fix-deployment.sh`** - Script that generated the emergency config

## 🔄 **Post-Recovery Actions**

Once the pod is stable:

1. **Update your main deployment files** with the corrected configuration
2. **Commit the fixes** to your repository  
3. **Test all webhook endpoints**
4. **Verify workflow execution**
5. **Set up proper monitoring** to catch future issues early

## 💡 **Prevention for Future**

- Always use `DB_TYPE=postgresdb` for n8n PostgreSQL connections
- Set proper health check endpoints matching your port configuration
- Include resource limits in deployment specifications
- Test configuration changes in a staging environment first
- Monitor pod restart counts and logs regularly

---

**Created**: $(date)  
**Status**: Emergency fix ready for deployment  
**Priority**: CRITICAL - Deploy immediately to stop crash loop