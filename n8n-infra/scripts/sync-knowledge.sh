#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KNOW_DIR="$ROOT_DIR/knowledge"
ENV_FILE="$ROOT_DIR/config/.env"

if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

declare -A REPOS=(
  ["n8n"]="https://github.com/danilonovaisv/CHATGPT-knowledge-base.git#projects/n8n"
  ["videos-e-animacoes"]="https://github.com/danilonovaisv/CHATGPT-knowledge-base.git#projects/videos-e-animacoes"
  ["midjourney-prompt"]="https://github.com/danilonovaisv/CHATGPT-knowledge-base.git#projects/midjorney-prompt"
)

clone_or_update() {
  local target_subdir="$1"; shift
  local url_ref="$1"; shift

  local url="${url_ref%%#*}"
  local ref="${url_ref#*#}"

  local target_dir="$KNOW_DIR/$target_subdir"
  mkdir -p "$target_dir"

  if [ ! -d "$target_dir/.git" ]; then
    echo "==> Cloning $url into $target_dir"
    git clone --depth 1 "$url" "$target_dir"
  else
    echo "==> Updating $target_dir"
    (cd "$target_dir" && git fetch --depth 1 origin && git reset --hard origin/HEAD)
  fi

  # If a subfolder ref is provided, mirror its content to the subdir root
  if [ -n "$ref" ] && [ -d "$target_dir/$ref" ]; then
    echo "==> Mirroring subfolder $ref into $target_dir"
    rsync -a --delete "$target_dir/$ref/" "$target_dir/"
    # Optionally, remove the rest of the cloned repo (keeping only desired content)
    find "$target_dir" -mindepth 1 -maxdepth 1 -not -name "$(basename "$ref")" -not -name ".git" -exec rm -rf {} + || true
  fi
}

for key in "${!REPOS[@]}"; do
  clone_or_update "$key" "${REPOS[$key]}"
done

echo "==> Knowledge repos synced"

# Ingestion: choose one of the strategies below.

# Strategy A: Trigger an n8n ingestion workflow via webhook.
# Requires WEBHOOK_URL to point to a workflow expecting payload with paths.
if [[ -n "${WEBHOOK_URL:-}" ]]; then
  echo "==> Triggering n8n webhook for ingestion"
  curl -fsSL -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "{\n      \"paths\": [\"$KNOW_DIR/n8n\", \"$KNOW_DIR/videos-e-animacoes\", \"$KNOW_DIR/midjourney-prompt\"],\n      \"vector_target\": \"${QDRANT_URL:-pgvector}\"\n    }" >/dev/null || true
else
  echo "==> No WEBHOOK_URL set. Skipping ingestion trigger."
fi

echo "==> Sync completed"

