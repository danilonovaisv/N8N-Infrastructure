ARG N8N_BASE_TAG=1.111.0
FROM n8nio/n8n:${N8N_BASE_TAG}

USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates tzdata \
 && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /data/.n8n && chown -R node:node /data
USER node
WORKDIR /data
