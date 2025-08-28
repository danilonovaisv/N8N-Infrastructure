# Base: pinned n8n image (do not use latest)
FROM n8nio/n8n:1.53.1

# Switch to root to install deps
USER root

# Install OS tools: git, curl, jq, Postgres client, Python, and Google Cloud CLI
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      git curl jq postgresql-client python3 python3-pip ca-certificates gnupg && \
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg && \
    apt-get update && apt-get install -y --no-install-recommends google-cloud-cli && \
    rm -rf /var/lib/apt/lists/*

# Create directories for custom packages and knowledge/workflows mounts
RUN mkdir -p /home/node/.n8n/custom \
    && chown -R node:node /home/node/.n8n

# Enable community nodes and declare default packages (adjust as needed)
ENV N8N_ENABLE_COMMUNITY_NODES=true \
    N8N_COMMUNITY_PACKAGES='["n8n-nodes-langchain", "n8n-nodes-google", "n8n-nodes-vertexai"]'

# Drop back to the n8n user
USER node

# Expose default n8n port
EXPOSE 5678

# n8n entrypoint is provided by the base image

