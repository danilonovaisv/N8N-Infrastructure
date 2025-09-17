# 🚀 Hugging Face Spaces Setup Instructions

## Prerequisites

1. **Hugging Face Account**: Make sure you have a Hugging Face account
2. **Hugging Face Token**: Create a write token at https://huggingface.co/settings/tokens
3. **GitHub Repository**: This repository with proper secrets configured

## Step 1: Create the Hugging Face Space

1. Go to https://huggingface.co/spaces
2. Click "Create new Space"
3. Set the following configuration:
   - **Space name**: `n8n-dan`
   - **Owner**: `danilonovais` 
   - **SDK**: Docker
   - **Visibility**: Public (or Private as needed)
   - **Hardware**: CPU basic (can upgrade later if needed)

## Step 2: Configure GitHub Secrets

In your GitHub repository, go to **Settings → Secrets and variables → Actions** and add:

### Required Secrets:
- **`HF_TOKEN`**: Your Hugging Face write token from Step 1
- **`DB_POSTGRESDB_PASSWORD`**: `An@10011982@@` (your database password)

### The workflow will automatically use:
- **HF_SPACE_NAME**: `danilonovais/n8n-dan`
- **SPACE_URL**: `https://danilonovais-n8n-dan.hf.space`

## Step 3: Configure Hugging Face Space Environment Variables

In your HF Space settings (https://huggingface.co/spaces/danilonovais/n8n-dan/settings), add these **Secrets**:

```bash
# Database Configuration
DB_POSTGRESDB_PASSWORD=An@10011982@@

# Optional: Additional configuration secrets
HF_TOKEN=your_hugging_face_token_here
```

The following **Variables** will be loaded from the `.env.hf` file automatically:
- `DB_TYPE=postgresdb`
- `DB_POSTGRESDB_HOST=aws-1-sa-east-1.pooler.supabase.com`
- `DB_POSTGRESDB_PORT=6543`
- `DB_POSTGRESDB_DATABASE=postgres`
- `DB_POSTGRESDB_USER=postgres.vkgwjmvekrlrjybbmtks`
- `DB_POSTGRESDB_SSL=true`

## Step 4: Deploy

### Automatic Deployment
The GitHub Actions workflow will automatically deploy when:
- You push to the `main` branch
- Daily at 4 AM UTC (scheduled)
- Manually triggered via GitHub Actions

### Manual Deployment
```bash
# Trigger manual deployment
gh workflow run deploy-to-hf.yml
```

## Step 5: Verify Deployment

1. **Check GitHub Actions**: Make sure the workflow completes successfully
2. **Check HF Space**: Visit https://danilonovais-n8n-dan.hf.space
3. **Test API endpoints**:
   - Health: https://danilonovais-n8n-dan.hf.space/health
   - API Docs: https://danilonovais-n8n-dan.hf.space/docs
   - Workflows: https://danilonovais-n8n-dan.hf.space/api/workflows

## Troubleshooting

### Common Issues:

1. **Space not found**: Make sure the space `danilonovais/n8n-dan` exists on HF
2. **Token permissions**: Ensure HF_TOKEN has write access to the space
3. **Database connection**: Check that Supabase database credentials are correct
4. **Build failures**: Check HF Space logs in the Space settings

### Logs:
- **GitHub Actions**: Check workflow run logs
- **HF Space**: Check the "Logs" tab in your Space settings
- **Application**: Logs will show database connection status and indexing progress

## Features After Deployment

✅ **N8N Workflow Documentation API**  
✅ **PostgreSQL Database Integration**  
✅ **2000+ Workflow Templates**  
✅ **Advanced Search & Filtering**  
✅ **RESTful API with Swagger Docs**  
✅ **Health Monitoring**  
✅ **Automated Daily Updates**  

## API Endpoints

- `GET /` - Web interface
- `GET /health` - Health check
- `GET /docs` - Interactive API documentation
- `GET /api/workflows` - Search workflows
- `GET /api/stats` - Database statistics
- `GET /api/workflows/{filename}` - Workflow details

## Support

If you encounter issues:
1. Check the logs in both GitHub Actions and HF Space
2. Verify all secrets and environment variables are set correctly
3. Ensure database connectivity from HF Spaces to Supabase