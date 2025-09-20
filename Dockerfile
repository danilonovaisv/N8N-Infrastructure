# Dockerfile
ARG N8N_BASE_TAG=latest
FROM n8nio/n8n:${N8N_BASE_TAG}

# Precisamos instalar só o mínimo (curl/ca-certificates/tzdata) e continuar rodando como não-root.
USER root
RUN set -eux; \
    if command -v apk >/dev/null 2>&1; then \
      apk add --no-cache curl ca-certificates tzdata; \
    elif command -v apt-get >/dev/null 2>&1; then \
      apt-get update && \
      apt-get install -y --no-install-recommends curl ca-certificates tzdata && \
      rm -rf /var/lib/apt/lists/*; \
    else \
      echo "Nenhum gerenciador de pacotes suportado encontrado" >&2; exit 1; \
    fi

# Diretório de dados alinhado ao compose
RUN mkdir -p /data/.n8n && chown -R node:node /data

USER node
WORKDIR /data
# A imagem oficial já define ENTRYPOINT/CMD do n8n
