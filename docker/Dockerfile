# Production-ready n8n Dockerfile for Hugging Face Spaces
FROM n8nio/n8n:1.17.1

# Set environment for production
ENV NODE_ENV=production
ENV N8N_PORT=7860
ENV N8N_LISTEN_ADDRESS=0.0.0.0
ENV N8N_PROTOCOL=https
ENV N8N_METRICS=true
ENV N8N_LOG_LEVEL=info
ENV N8N_LOG_OUTPUT=console
ENV EXECUTIONS_MODE=queue
ENV N8N_DISABLE_UI=false

# Create app user for security
USER root

# Install additional dependencies for AI and automation
RUN apk add --no-cache \
    curl \
    git \
    python3 \
    py3-pip \
    postgresql-client \
    && pip3 install --no-cache-dir \
    langchain \
    chromadb \
    sentence-transformers

# Create necessary directories
RUN mkdir -p /home/node/.n8n/custom \
    && mkdir -p /home/node/.n8n/nodes \
    && mkdir -p /home/node/.n8n/credentials \
    && mkdir -p /home/node/knowledge

# Copy custom configurations
COPY config/custom-nodes.json /home/node/.n8n/custom/
COPY knowledge/ /home/node/knowledge/

# Set proper permissions
RUN chown -R node:node /home/node/.n8n \
    && chown -R node:node /home/node/knowledge \
    && chmod +x /home/node/knowledge/sync-*.sh

# Switch back to node user
USER node

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:7860/healthz || exit 1

# Expose port for Hugging Face Spaces
EXPOSE 7860

# Start n8n
CMD ["n8n", "start"]