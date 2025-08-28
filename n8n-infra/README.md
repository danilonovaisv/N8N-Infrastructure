# n8n Infrastructure on Hugging Face Spaces + Supabase

This repository provides infra-as-code, Docker assets, automation scripts, and CI/CD to run a self-hosted n8n instance on Hugging Face Spaces with Supabase (Postgres + SSL) as the database, optional vector store, and knowledge base sync.

## Overview

- Containerization: Docker (pinned n8n version) and Docker Compose
- Orchestration: Hugging Face Spaces (Docker Space)
- Database: Supabase Postgres (SSL required)
- Vector Store: pgvector on Supabase or optional Qdrant service for local dev
- Integrations: GitHub, Google Cloud CLI, Vertex AI, LangChain community nodes
- Automation: Backups (DB + workflows), knowledge sync, CI/CD with GitHub Actions

## Repository Structure

```
n8n-infra/
  docker/
    Dockerfile
    docker-compose.yml
  config/
    .env.example
    credentials/
  workflows/
    backup/
  knowledge/
    n8n/
    videos-e-animacoes/
    midjourney-prompt/
  scripts/
    backup.sh
    restore.sh
    sync-knowledge.sh
  .github/
    workflows/
      deploy-to-hf.yml
      backup-workflows.yml
      sync-knowledge.yml
  README.md
```

Notes:
- CI files are in `.github/workflows` (standard for GitHub Actions).
- Secrets are provided via repo/Actions secrets or environment variables at runtime.

## Prerequisites

- Supabase project with SSL enabled and (optionally) pgvector extension enabled
- Hugging Face account with a Docker Space created
- GitHub repository (this repo) with Actions enabled
- Local: Docker and Docker Compose installed

## Configuration

1) Copy the env template and fill values:

```
cp config/.env.example config/.env
```

Key variables (see `config/.env.example` for full list):
- N8N_ENCRYPTION_KEY, N8N_USER_MANAGEMENT_JWT_SECRET
- DB_* for Supabase (host, db, user, password) with `DB_POSTGRESDB_SSL=true`
- WEBHOOK_URL (public URL for n8n webhooks)
- HF_TOKEN, GITHUB_TOKEN (for CI/CD & sync jobs)
- GOOGLE_PROJECT_ID, GOOGLE_CREDENTIALS_PATH (if using Google/Vertex)
- N8N_API_KEY and N8N_URL for workflow export API

Store any OAuth JSON/keyfiles under `config/credentials/` (keep them out of Git).

Placeholders to populate in `config/.env` (high priority):
- N8N_ENCRYPTION_KEY=
- N8N_USER_MANAGEMENT_JWT_SECRET=
- DB_TYPE=postgresdb
- DB_POSTGRESDB_HOST=
- DB_POSTGRESDB_PORT=5432
- DB_POSTGRESDB_DATABASE=
- DB_POSTGRESDB_USER=
- DB_POSTGRESDB_PASSWORD=
- DB_POSTGRESDB_SSL=true
- WEBHOOK_URL=
- HF_TOKEN=
- GITHUB_TOKEN=
- GOOGLE_PROJECT_ID=
- GOOGLE_CREDENTIALS_PATH=

## Local Development with Docker Compose

1) Ensure `config/.env` is present and valid. For local testing you can point to Supabase or a local Postgres; for Supabase, keep SSL enabled.

2) Start services:

```
cd n8n-infra/docker
docker compose --env-file ../config/.env up -d
```

Services:
- n8n: http://localhost:5678 (first user registration on first run)
- Optional vector DB: Qdrant at http://localhost:6333

3) Stop services:

```
docker compose --env-file ../config/.env down
```

## Deploy on Hugging Face Spaces (Docker)

1) Create a Space (type: Docker) on Hugging Face.

2) Configure repository secrets in GitHub:
- `HF_TOKEN`: a write token for the Space
- `HF_SPACE_ID`: e.g. `org-or-user/space-name`

3) CI/CD: The workflow `deploy-to-hf.yml` pushes a minimal Space repository that contains the Dockerfile. On push to `main` or manual dispatch, it:
- Copies `n8n-infra/docker/Dockerfile` to a temporary directory
- Commits and pushes that directory to the Space git repo
- Requests a Space restart/rebuild

You can customize the pushed contents if you need additional runtime assets.

4) Space Secrets: In the Space settings, define the same environment variables as in `config/.env` for production (e.g., DB_*, N8N_ENCRYPTION_KEY, N8N_USER_MANAGEMENT_JWT_SECRET, WEBHOOK_URL, GOOGLE_*). These are injected at container runtime.

## Supabase Setup

1) Create a Supabase project and note the host, database, user, and password.

2) SSL enforcement:
- Keep `DB_POSTGRESDB_SSL=true`
- If Supabase requires, set `DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED=false`

3) Vector support:
- Option A (recommended): Enable pgvector on your Supabase Postgres for unified storage of embeddings.
- Option B: Use an external vector DB (e.g., Qdrant) for local dev or if preferred.

## Backups and Restores

Workflows and DB backups can run locally or via GitHub Actions.

- Backup script:
  - DB: `pg_dump` with SSL required
  - Workflows: Export via n8n REST API (`N8N_URL` + `N8N_API_KEY`)

Run locally:

```
bash n8n-infra/scripts/backup.sh
```

Restore locally (from a `.sql` dump):

```
bash n8n-infra/scripts/restore.sh path/to/backup.sql
```

Nightly backups via Actions: see `.github/workflows/backup-workflows.yml`.

## Knowledge Base Sync

The `sync-knowledge.sh` script pulls the specified GitHub repos into `n8n-infra/knowledge/` and then triggers ingestion (either via an n8n webhook you define or your own ingestion script) into your chosen vector store (pgvector or Qdrant).

Run locally:

```
bash n8n-infra/scripts/sync-knowledge.sh
```

Automated: see `.github/workflows/sync-knowledge.yml`.

## LangChain, Agents, and Community Nodes

The Dockerfile enables community nodes and includes a placeholder list via `N8N_COMMUNITY_PACKAGES`. Add or adjust packages for LangChain, Google APIs, Vertex AI, etc. Configure related credentials via environment variables and `config/credentials/`.

Notes for n8n community nodes:
- Ensure `N8N_ENABLE_COMMUNITY_NODES=true`
- Set `N8N_COMMUNITY_PACKAGES` to include packages like `n8n-nodes-langchain`, `n8n-nodes-google`, and any Vertex AI integrations you use.
- After first run, verify nodes appear in the n8n editor.

## Rollback Strategy

- Hugging Face Space: Use the Space’s git history to roll back to a previous commit or re-run a prior successful build.
- GitHub Actions: Redeploy a previous commit via workflow “Run workflow” (manual dispatch).
- Database: Restore using `scripts/restore.sh` from a prior `.sql` dump.

## Security Notes

- Never commit real secrets. Use `config/.env` locally and GitHub Actions secrets in CI.
- Use SSL for DB connections (`DB_POSTGRESDB_SSL=true`). For Supabase, set `DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED=false` if required.
- Rotate keys regularly (`N8N_ENCRYPTION_KEY`, `N8N_USER_MANAGEMENT_JWT_SECRET`).
