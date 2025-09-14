---
license: apache-2.0
title: danilonovais/n8n-dan
sdk: docker
emoji: 🚀
colorFrom: purple
colorTo: blue
pinned: true
short_description: ' **n8n**: Self-hosted workflow automation platform.'
---

# n8n Infrastructure Repository

> **⚠️ Security Warning**
> A `.env` file with sensitive credentials was previously committed to this repository. Although the file has been removed, the credentials may still be present in the Git history. **It is crucial that you scrub the Git history of this repository and rotate all exposed secrets (API keys, database passwords, etc.) immediately.** Tools like [bfg-repo-cleaner](https://rtyley.github.io/bfg-repo-cleaner/) can help with this process.

A comprehensive, production-ready infrastructure setup for deploying n8n automation platform on Hugging Face Spaces with AI integrations and automated knowledge management.

## 🚀 Features

### Core Platform
- **n8n**: Self-hosted workflow automation platform.
- **Hugging Face Spaces**: Docker-based deployment with automatic scaling.
- **Supabase PostgreSQL**: SSL-encrypted database with pgvector extension.
- **ChromaDB**: Vector store for embeddings and AI-powered search.

### AI & Automation
- **LangChain Integration**: Advanced AI workflow capabilities.
- **Multi-Model Support**: OpenAI GPT, Anthropic Claude, Google Vertex AI.
- **Vector Knowledge Base**: Automated content ingestion with embeddings.
- **Community Nodes**: Extended functionality with custom AI nodes.

### DevOps & Security
- **GitHub Actions CI/CD**: Automated deployment and maintenance.
- **Optimized Docker Setup**: Non-root user and healthchecks for enhanced security and reliability.
- **Automated Full Backups**: Daily backups of database, workflows, and credentials.
- **Database Security**: Row Level Security (RLS) enabled by default.
- **Knowledge Sync**: Multi-repository content synchronization.

## 📋 Prerequisites

- **GitHub Account**
- **Hugging Face Account**
- **Supabase Account**
- **Git** and **Docker** installed locally

## 🛠️ Quick Start

### 1. Repository Setup
```bash
# Clone the repository
git clone https://github.com/your-username/n8n-infra.git
cd n8n-infra

# Create your local environment configuration from the example
cp config/.env.example config/.env

# Edit config/.env with your actual values.
# NEVER commit this file to Git.
```

### 2. Local Development
```bash
# Start the full stack locally
docker compose -f docker/docker-compose.yml up -d

# Check service status
docker compose -f docker/docker-compose.yml ps

# View logs
docker compose -f docker/docker-compose.yml logs -f n8n
```

### 3. Hugging Face Deployment
The repository is configured to automatically deploy to a Hugging Face Space on every push to the `main` branch.
```bash
# Trigger deployment via GitHub Actions
git push origin main

# Or deploy manually
gh workflow run deploy-to-hf.yml
```

## 📊 Database Setup
The authoritative schema is defined in `supabase/schema.sql`. It is recommended to apply this schema to your Supabase project via the Supabase UI SQL Editor or by using Supabase migrations.

Key features of the schema include:
- A `knowledge` schema to encapsulate all knowledge base tables.
- `documents` and `embeddings` tables for storing content and its vector embeddings.
- A `vector_l2_ops` index on the `embeddings` table for efficient similarity search.
- **Row Level Security (RLS)** enabled on all tables to control data access. By default, data is public for reading, but only the `service_role` can write data.

## 💾 Backup & Recovery

### Automated Backups
The `.github/workflows/backup-workflows.yml` GitHub Action runs nightly to create a full backup of your n8n instance. Each backup is a `.tar.gz` archive that includes:
- A full dump of the PostgreSQL database.
- A JSON export of all your n8n workflows.
- A copy of your `config` directory, which contains n8n credentials and settings.

### Manual Backup
To create a backup manually, you can run the `backup.sh` script. This requires you to have the necessary environment variables set (see `config/.env.example`).
```bash
# Make sure the script is executable
chmod +x scripts/backup.sh

# Run the script
./scripts/backup.sh
```

### Restore from Backup
To restore your n8n instance from a backup, use the `restore.sh` script.

**Warning:** This process will overwrite your existing database and configuration.

1.  **Stop your n8n container** to prevent data corruption.
    ```bash
    docker compose -f docker/docker-compose.yml stop n8n
    ```
2.  Run the `restore.sh` script, providing the path to your backup file.
    ```bash
    # Make sure the script is executable
    chmod +x scripts/restore.sh

    # Run the restore script
    BACKUP_FILE=workflows/backup/n8n-backup-YYYYMMDD-HHMMSS.tar.gz ./scripts/restore.sh
    ```
3.  The script will guide you through the process. It will restore the database and the `config` directory.
4.  For workflows, the script will provide a `restored_workflows_*.json` file. You will need to import this file manually via the n8n UI or by using the `n8n-cli`.
5.  **Restart your n8n container.**
    ```bash
    docker compose -f docker/docker-compose.yml start n8n
    ```

## 🔒 Security
This repository has been optimized with security in mind.

- **Credential Management**: A `.gitignore` file is included to prevent committing sensitive files like `.env`. An example file `config/.env.example` is provided.
- **Container Security**: The `Dockerfile` is configured to run n8n as a non-root user, reducing the container's attack surface.
- **Database Security**: Row Level Security is enabled in the database schema (`supabase/schema.sql`).
- **Secret Rotation**: As mentioned in the security warning, it is critical to rotate any secrets that may have been exposed in the Git history.

## 🔧 Maintenance

### Health Monitoring
```bash
# Check container health (includes a healthcheck)
docker compose -f docker/docker-compose.yml ps

# View application logs
docker compose -f docker/docker-compose.yml logs -f n8n
```

### Performance Tuning
**Container Resources**: Resource limits are defined in `docker-compose.yml` to prevent resource exhaustion during local development.
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

## 🔄 CI/CD Pipeline
The CI/CD pipelines are defined in the `.github/workflows` directory and are optimized for:
- **Efficiency**: The backup workflow uses a pre-built Docker container, and the knowledge sync workflow uses dependency caching to speed up execution.
- **Reliability**: The knowledge sync workflow uses `npm ci` for deterministic builds.

---
_This README has been updated to reflect the infrastructure audit and optimization._
