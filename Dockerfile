FROM node:24-alpine

# Dependências mínimas do n8n
RUN apk add --no-cache bash curl openssl chromium postgresql-client git \
    && npm i -g n8n@1.108.0

# Environment variables
ENV N8N_USER_FOLDER=/data/.n8n
ENV PUPPETEER_SKIP_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
ENV N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
ENV PATH=/usr/local/bin:$PATH

WORKDIR /data
COPY app.sh /app.sh
RUN chmod +x /app.sh

# --- AJUSTE AQUI ---
# Garante que o usuário 'node' tenha permissão para escrever no diretório /data
RUN chown -R node:node /data

# Rode como usuário node
USER node

EXPOSE 5678
CMD ["/bin/bash", "/app.sh"]
