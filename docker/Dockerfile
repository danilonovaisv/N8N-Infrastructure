# Pin the n8n version for predictable upgrades/rollbacks
FROM n8nio/n8n:1.108.2

# Hugging Face Spaces injects $PORT; n8n should listen on it
ARG PORT=6543
ARG WEBHOOK_URL=https://danilonovais-n8n-dan.hf.space
ENV PORT=$PORT
ENV WEBHOOK_URL=$WEBHOOK_URL
# Public URL (important for webhooks behind HF proxy)
ENV WEBHOOK_URL=${WEBHOOK_URL}

# Execution & retention (production-friendly defaults)
ENV EXECUTIONS_MODE=regular
ENV EXECUTIONS_DATA_SAVE_ON_ERROR=all
ENV EXECUTIONS_DATA_SAVE_ON_SUCCESS=none
ENV EXECUTIONS_DATA_PRUNE=true
ENV EXECUTIONS_DATA_MAX_AGE=336
ENV QUEUE_BULL_REDIS_DISABLED=true

# Health/metrics
ENV N8N_METRICS=true
ENV QUEUE_HEALTH_CHECK_ACTIVE=true

# Add healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f "http://localhost:${N8N_PORT:-5678}/healthz" || exit 1

# Switch to non-root user for security
USER node

# Database (set via Secrets in HF Space)
# ENV DB_TYPE=postgresdb
# ENV DB_POSTGRESDB_HOST=
# ENV DB_POSTGRESDB_PORT=5432
# ENV DB_POSTGRESDB_DATABASE=
# ENV DB_POSTGRESDB_USER=
# ENV DB_POSTGRESDB_PASSWORD=
# ENV DB_POSTGRESDB_SCHEMA=public
# ENV DB_POSTGRESDB_SSL=true
# ENV DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED=false

# Security
# ENV N8N_ENCRYPTION_KEY=
# ENV N8N_USER_MANAGEMENT_JWT_SECRET=
# Optional: protect UI with Basic Auth
# ENV N8N_BASIC_AUTH_ACTIVE=true
# ENV N8N_BASIC_AUTH_USER=
# ENV N8N_BASIC_AUTH_PASSWORD=
