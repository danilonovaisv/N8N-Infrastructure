# n8n Infrastructure Repository

A comprehensive, production-ready infrastructure setup for deploying n8n automation platform on Hugging Face Spaces with AI integrations and automated knowledge management.

## 🚀 Features

### Core Platform

- **n8n v1.17.1**: Self-hosted workflow automation platform
- **Hugging Face Spaces**: Docker-based deployment with automatic scaling
- **Supabase PostgreSQL**: SSL-encrypted database with pgvector extension
- **ChromaDB**: Vector store for embeddings and AI-powered search

### AI & Automation

- **LangChain Integration**: Advanced AI workflow capabilities
- **Multi-Model Support**: OpenAI GPT, Anthropic Claude, Google Vertex AI
- **Vector Knowledge Base**: Automated content ingestion with embeddings
- **Community Nodes**: Extended functionality with custom AI nodes

### DevOps & Monitoring

- **GitHub Actions CI/CD**: Automated deployment and maintenance
- **Automated Backups**: Daily workflow and configuration backups
- **Knowledge Sync**: Multi-repository content synchronization
- **Health Monitoring**: Container health checks and alerting

## 📋 Prerequisites

Before setting up the infrastructure, ensure you have:

1. **GitHub Account** with repository access
2. **Hugging Face Account** with Spaces access
3. **Supabase Account** with PostgreSQL database
4. **Git** and **Docker** installed locally

### Required Secrets

Configure these secrets in your GitHub repository settings:

```bash
# Hugging Face
HF_USERNAME=your-huggingface-username
HF_TOKEN=your-hf-token
HF_SPACE_NAME=n8n-automation

# Database
DB_POSTGRESDB_HOST=your-project.supabase.co
DB_POSTGRESDB_USER=postgres
DB_POSTGRESDB_PASSWORD=your-database-password
DB_POSTGRESDB_DATABASE=postgres

# n8n Configuration
N8N_ENCRYPTION_KEY=your-32-character-encryption-key
N8N_USER_MANAGEMENT_JWT_SECRET=your-jwt-secret
WEBHOOK_URL=https://your-username-n8n-automation.hf.space

# AI Services (Optional)
OPENAI_API_KEY=sk-your-openai-key
ANTHROPIC_API_KEY=sk-ant-your-anthropic-key
GOOGLE_PROJECT_ID=your-gcp-project
```

## 🛠️ Quick Start

### 1. Repository Setup

```bash
# Clone the repository
git clone https://github.com/your-username/n8n-infra.git
cd n8n-infra

# Create environment configuration
cp config/.env.example .env
# Edit .env with your actual values
```

### 2. Local Development

```bash
# Start the full stack locally
docker-compose -f docker/docker-compose.yml up -d

# Check service status
docker-compose -f docker/docker-compose.yml ps

# View logs
docker-compose -f docker/docker-compose.yml logs -f n8n
```

### 3. Hugging Face Deployment

```bash
# Trigger deployment via GitHub Actions
git push origin main

# Or deploy manually
gh workflow run deploy-to-hf.yml
```

## 📊 Database Setup

### Supabase Configuration

1. **Create Supabase Project**:

   ```sql
   -- Enable pgvector extension
   CREATE EXTENSION IF NOT EXISTS vector;

   -- Create knowledge base schema
   CREATE SCHEMA IF NOT EXISTS knowledge;

   -- Create embeddings table
   CREATE TABLE knowledge.embeddings (
     id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
     content_id TEXT NOT NULL,
     collection_name TEXT NOT NULL,
     content TEXT NOT NULL,
     embedding VECTOR(384),
     metadata JSONB DEFAULT '{}',
     created_at TIMESTAMPTZ DEFAULT NOW(),
     updated_at TIMESTAMPTZ DEFAULT NOW()
   );

   -- Create indexes for performance
   CREATE INDEX IF NOT EXISTS idx_embeddings_collection ON knowledge.embeddings(collection_name);
   CREATE INDEX IF NOT EXISTS idx_embeddings_content_id ON knowledge.embeddings(content_id);
   CREATE INDEX IF NOT EXISTS idx_embeddings_vector ON knowledge.embeddings
   USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
   ```

2. **Configure Row Level Security**:

   ```sql
   -- Enable RLS
   ALTER TABLE knowledge.embeddings ENABLE ROW LEVEL SECURITY;

   -- Allow authenticated users to read embeddings
   CREATE POLICY "Users can read embeddings" ON knowledge.embeddings
     FOR SELECT TO authenticated USING (true);

   -- Allow service role to manage embeddings
   CREATE POLICY "Service role can manage embeddings" ON knowledge.embeddings
     FOR ALL TO service_role USING (true);
   ```

## 🤖 AI Integration Guide

### LangChain Workflows

The platform supports advanced LangChain workflows:

```javascript
// Example: Knowledge-based Q&A workflow
{
  "nodes": [
    {
      "name": "Vector Search",
      "type": "n8n-nodes-vector-store",
      "parameters": {
        "operation": "similarity_search",
        "query": "{{ $json.question }}",
        "collection": "n8n",
        "top_k": 5
      }
    },
    {
      "name": "LangChain QA",
      "type": "@n8n/n8n-nodes-langchain",
      "parameters": {
        "chain_type": "question_answering",
        "context": "{{ $json.vector_results }}",
        "question": "{{ $json.question }}"
      }
    }
  ]
}
```

### Custom AI Nodes

Install additional AI nodes:

```bash
# Install in running container
docker exec n8n-automation npm install n8n-nodes-google-vertex-ai
docker exec n8n-automation npm install n8n-nodes-openai-advanced

# Restart to load new nodes
docker-compose -f docker/docker-compose.yml restart n8n
```

## 🗄️ Knowledge Management

### Automated Synchronization

The system automatically syncs content from these repositories:

- **n8n Knowledge**: `/projects/n8n` - Workflow examples and best practices
- **Video & Animation**: `/projects/videos-e-animacoes` - Multimedia processing guides
- **Midjourney Prompts**: `/projects/midjorney-prompt` - AI art generation prompts

### Manual Knowledge Sync

```bash
# Sync specific collection
./scripts/sync-knowledge.sh

# Or trigger via GitHub Actions
gh workflow run sync-knowledge.yml -f collections=n8n,midjourney-prompt
```

### Vector Search Setup

Query the knowledge base in n8n workflows:

```javascript
// Vector similarity search node configuration
{
  "collection": "n8n",
  "query": "How to create webhook workflows",
  "top_k": 3,
  "score_threshold": 0.7
}
```

## 💾 Backup & Recovery

### Automated Backups

Daily backups include:

- All n8n workflows (exported as JSON)
- Encrypted credentials
- Database schema
- Knowledge base content
- Vector embeddings

### Manual Backup

```bash
# Create full backup
./scripts/backup.sh custom-backup-name

# List available backups
ls workflows/backup/

# Restore from backup
./scripts/restore.sh n8n_backup_20240115_140230
```

### Backup Schedule

- **Daily**: Automated workflow backup at 2 AM UTC
- **Weekly**: Full system backup including database
- **On-demand**: Manual backups via GitHub Actions

## 🔧 Maintenance

### Health Monitoring

```bash
# Check container health
docker-compose -f docker/docker-compose.yml ps

# View application logs
docker-compose -f docker/docker-compose.yml logs -f n8n

# Monitor vector store
curl http://localhost:8000/api/v1/heartbeat
```

### Performance Tuning

**Database Optimization**:

```sql
-- Monitor query performance
SELECT query, mean_exec_time, calls
FROM pg_stat_statements
WHERE query LIKE '%n8n%'
ORDER BY mean_exec_time DESC
LIMIT 10;

-- Optimize vector searches
SET ivfflat.probes = 10;
```

**Container Resources**:

```yaml
# docker-compose.yml resource limits
services:
  n8n:
    deploy:
      resources:
        limits:
          cpus: "2.0"
          memory: 4G
        reservations:
          cpus: "1.0"
          memory: 2G
```

## 🔒 Security

### SSL Configuration

- All database connections use SSL encryption
- Webhook URLs must use HTTPS
- Container communication over encrypted networks

### Credential Management

```bash
# Credentials are encrypted by n8n
# Store sensitive files in config/credentials/
mkdir -p config/credentials
echo '{}' > config/credentials/google-service-account.json

# Set proper permissions
chmod 600 config/credentials/*
```

### Environment Security

- Never commit `.env` files
- Use GitHub Secrets for sensitive data
- Rotate encryption keys regularly
- Enable Supabase RLS policies

## 🚨 Troubleshooting

### Common Issues

**Connection Problems**:

```bash
# Test database connection
docker exec n8n-automation psql "$DB_POSTGRESDB_HOST" -U "$DB_POSTGRESDB_USER" -c "\l"

# Check n8n logs
docker logs n8n-automation --tail 50

# Verify webhook connectivity
curl -I "$WEBHOOK_URL/healthz"
```

**Deployment Issues**:

```bash
# Check Hugging Face Space status
curl -I "https://huggingface.co/spaces/$HF_USERNAME/$HF_SPACE_NAME"

# View GitHub Actions logs
gh run list --workflow=deploy-to-hf.yml
gh run view [run-id] --log
```

**Knowledge Sync Problems**:

```bash
# Manual knowledge sync debug
./scripts/sync-knowledge.sh
echo $?  # Should return 0 for success

# Check embedding generation
python3 -c "
import json
with open('knowledge/n8n/n8n_embeddings.json') as f:
    data = json.load(f)
    print(f'Embeddings loaded: {len(data)} documents')
"
```

### Recovery Procedures

**Emergency Restore**:

1. Stop all services: `docker-compose down`
2. Restore from latest backup: `./scripts/restore.sh [backup-name]`
3. Restart services: `docker-compose up -d`
4. Verify functionality: Access web interface

**Database Recovery**:

```sql
-- Check database integrity
SELECT schemaname, tablename, n_tup_ins, n_tup_upd, n_tup_del
FROM pg_stat_user_tables
WHERE schemaname = 'public';

-- Rebuild vector indexes if needed
REINDEX INDEX idx_embeddings_vector;
```

## 📈 Scaling

### Horizontal Scaling

- Multiple n8n instances with queue mode
- Load balancer configuration
- Distributed vector store

### Performance Monitoring

- Enable n8n metrics: `N8N_METRICS=true`
- Database query monitoring
- Vector search performance tracking
- Container resource utilization

## 🔄 CI/CD Pipeline

### Workflow Triggers

- **Push to main**: Automatic deployment
- **Scheduled**: Daily backups and knowledge sync
- **Manual**: On-demand operations via GitHub Actions

### Pipeline Stages

1. **Build**: Docker image creation and testing
2. **Test**: Health checks and validation
3. **Deploy**: Hugging Face Spaces deployment
4. **Monitor**: Post-deployment verification

## 📝 Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature/new-capability`
3. Commit changes: `git commit -am 'Add new capability'`
4. Push branch: `git push origin feature/new-capability`
5. Submit pull request

### Development Workflow

```bash
# Local development
docker-compose -f docker/docker-compose.yml up --build

# Run tests
./scripts/test-infrastructure.sh

# Deploy to staging
gh workflow run deploy-to-hf.yml -f force_deploy=true
```

## 📞 Support

- **Issues**: GitHub Issues
- **Documentation**: [n8n Documentation](https://docs.n8n.io)
- **Community**: [n8n Community](https://community.n8n.io)

## 📄 License

This project is licensed under the Apache License 2.0 - see the LICENSE file for details.

---

**⚡ Pro Tips**:

1. **Performance**: Use queue mode for high-volume workflows
2. **Security**: Regular credential rotation and access reviews
3. **Monitoring**: Set up alerts for failed workflows and system health
4. **Backup**: Test restore procedures regularly
5. **Knowledge**: Keep your knowledge base updated with latest best practices

---

_Built with ❤️ for the n8n automation community_

### ChromaDB

ChromaDB é utilizado como vector store para armazenar embeddings e permitir buscas semânticas avançadas nos fluxos de trabalho do n8n.

#### Configuração

1. **Obtenha seu token de autenticação (API Key) no painel do Chroma Cloud**.
2. No arquivo `.env`, adicione as variáveis:

   ```dotenv
   CHROMA_AUTH_TOKEN=ck-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   CHROMA_HOST=api.chroma.com
   CHROMA_PORT=443
   ```

3. Certifique-se de que o serviço Chroma está acessível e que o token está correto.

4. Para uso local, ajuste `CHROMA_HOST` para `localhost` e `CHROMA_PORT` para a porta configurada.

#### Referências

- [Documentação ChromaDB](https://docs.trychroma.com/)
- [Como gerar API Key no Chroma Cloud](https://docs.trychroma.com/cloud)
