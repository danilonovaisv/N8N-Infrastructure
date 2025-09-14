#!/bin/bash

# Knowledge Base Synchronization Script
# Syncs content from multiple GitHub repositories and generates embeddings
# Usage: ./sync-knowledge.sh

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
KNOWLEDGE_DIR="$PROJECT_ROOT/knowledge"
TEMP_DIR="/tmp/kb-sync-$$"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
}

# Set trap for cleanup
trap cleanup EXIT

# Check dependencies
check_dependencies() {
    local deps=("git" "curl" "jq")
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" > /dev/null; then
            log_error "Required dependency not found: $dep"
            exit 1
        fi
    done
}

# Load environment variables
load_env() {
    if [[ -f "$PROJECT_ROOT/.env" ]]; then
        source "$PROJECT_ROOT/.env"
    else
        log_error ".env file not found. Copy .env.example and configure it."
        exit 1
    fi
}

# Clone or update repository
sync_repository() {
    local repo_url="$1"
    local target_path="$2"
    local branch="${3:-main}"
    local subpath="$4"
    
    log_info "Syncing repository: $repo_url"
    log_debug "Target: $target_path, Branch: $branch, Subpath: $subpath"
    
    local repo_name=$(basename "$repo_url" .git)
    local temp_repo_path="$TEMP_DIR/$repo_name"
    
    # Clone repository to temp directory
    git clone --depth 1 --branch "$branch" "$repo_url" "$temp_repo_path" || {
        log_error "Failed to clone repository: $repo_url"
        return 1
    }
    
    # Copy specific subpath to target
    local source_path="$temp_repo_path/$subpath"
    if [[ -d "$source_path" ]]; then
        mkdir -p "$(dirname "$target_path")"
        cp -r "$source_path/." "$target_path/"
        log_info "Successfully synced to: $target_path"
    else
        log_warn "Subpath not found: $subpath in $repo_url"
        return 1
    fi
}

# Generate embeddings for knowledge content
generate_embeddings() {
    local knowledge_path="$1"
    local collection_name="$2"
    
    log_info "Generating embeddings for: $collection_name"
    
    # Create Python script for embedding generation
    cat > "$TEMP_DIR/generate_embeddings.py" << 'EOF'
import os
import json
import sys
from pathlib import Path
import hashlib
import requests
from sentence_transformers import SentenceTransformer

def load_model():
    """Load sentence transformer model"""
    try:
        model = SentenceTransformer('all-MiniLM-L6-v2')
        return model
    except Exception as e:
        print(f"Error loading model: {e}")
        return None

def process_text_files(knowledge_path, collection_name):
    """Process text files and generate embeddings"""
    model = load_model()
    if not model:
        return False
    
    embeddings_data = []
    knowledge_path = Path(knowledge_path)
    
    # Process markdown and text files
    for file_path in knowledge_path.rglob("*.md"):
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Generate embedding
            embedding = model.encode(content).tolist()
            
            # Create document metadata
            doc_id = hashlib.md5(str(file_path).encode()).hexdigest()
            
            embeddings_data.append({
                "id": doc_id,
                "content": content,
                "embedding": embedding,
                "metadata": {
                    "file_path": str(file_path.relative_to(knowledge_path)),
                    "file_name": file_path.name,
                    "collection": collection_name,
                    "content_type": "markdown",
                    "size": len(content)
                }
            })
            
        except Exception as e:
            print(f"Error processing file {file_path}: {e}")
    
    # Save embeddings to JSON file
    output_file = knowledge_path / f"{collection_name}_embeddings.json"
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(embeddings_data, f, indent=2, ensure_ascii=False)
    
    print(f"Generated {len(embeddings_data)} embeddings for {collection_name}")
    return True

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python generate_embeddings.py <knowledge_path> <collection_name>")
        sys.exit(1)
    
    knowledge_path = sys.argv[1]
    collection_name = sys.argv[2]
    
    if process_text_files(knowledge_path, collection_name):
        print("Embedding generation completed successfully")
    else:
        print("Embedding generation failed")
        sys.exit(1)
EOF

    # Run embedding generation
    python3 "$TEMP_DIR/generate_embeddings.py" "$knowledge_path" "$collection_name" || {
        log_error "Failed to generate embeddings for $collection_name"
        return 1
    }
}

# Upload embeddings to vector store
upload_embeddings() {
    local embeddings_file="$1"
    local collection_name="$2"
    
    log_info "Uploading embeddings to vector store: $collection_name"
    
    if [[ ! -f "$embeddings_file" ]]; then
        log_error "Embeddings file not found: $embeddings_file"
        return 1
    fi
    
    # Upload to ChromaDB
    local chroma_url="http://${CHROMA_HOST:-localhost}:${CHROMA_PORT:-8000}"
    
    curl -X POST "$chroma_url/api/v1/collections" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${CHROMA_AUTH_TOKEN}" \
        -d "{\"name\": \"$collection_name\"}" || true
    
    # Process and upload embeddings in batches
    python3 - << EOF
import json
import requests
import sys
from pathlib import Path

def upload_batch(embeddings_data, collection_name, chroma_url, auth_token):
    """Upload embeddings in batches to ChromaDB"""
    batch_size = 100
    total_docs = len(embeddings_data)
    
    for i in range(0, total_docs, batch_size):
        batch = embeddings_data[i:i+batch_size]
        
        # Prepare batch data for ChromaDB
        ids = [doc["id"] for doc in batch]
        embeddings = [doc["embedding"] for doc in batch]
        metadatas = [doc["metadata"] for doc in batch]
        documents = [doc["content"] for doc in batch]
        
        payload = {
            "ids": ids,
            "embeddings": embeddings,
            "metadatas": metadatas,
            "documents": documents
        }
        
        try:
            response = requests.post(
                f"{chroma_url}/api/v1/collections/{collection_name}/add",
                json=payload,
                headers={
                    "Content-Type": "application/json",
                    "Authorization": f"Bearer {auth_token}"
                },
                timeout=30
            )
            
            if response.status_code == 200:
                print(f"Uploaded batch {i//batch_size + 1} ({len(batch)} documents)")
            else:
                print(f"Error uploading batch {i//batch_size + 1}: {response.status_code}")
                print(f"Response: {response.text}")
                
        except Exception as e:
            print(f"Error uploading batch {i//batch_size + 1}: {e}")
            continue

# Load and upload embeddings
embeddings_file = "$embeddings_file"
collection_name = "$collection_name"
chroma_url = "$chroma_url"
auth_token = "${CHROMA_AUTH_TOKEN:-}"

try:
    with open(embeddings_file, 'r', encoding='utf-8') as f:
        embeddings_data = json.load(f)
    
    upload_batch(embeddings_data, collection_name, chroma_url, auth_token)
    print(f"Successfully uploaded {len(embeddings_data)} embeddings to {collection_name}")
    
except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)
EOF
}

# Sync all knowledge repositories
sync_all_repositories() {
    log_info "Starting knowledge base synchronization..."
    
    mkdir -p "$TEMP_DIR"
    
    # Repository configurations
    declare -A repos=(
        ["n8n"]="${KB_REPO_N8N:-}:${KB_PATH_N8N:-projects/n8n}"
        ["videos-e-animacoes"]="${KB_REPO_N8N:-}:${KB_PATH_VIDEOS:-projects/videos-e-animacoes}"
        ["midjourney-prompt"]="${KB_REPO_N8N:-}:${KB_PATH_MIDJOURNEY:-projects/midjorney-prompt}"
    )
    
    for collection in "${!repos[@]}"; do
        local repo_config="${repos[$collection]}"
        local repo_url=$(echo "$repo_config" | cut -d':' -f1)
        local subpath=$(echo "$repo_config" | cut -d':' -f2)
        local target_path="$KNOWLEDGE_DIR/$collection"
        
        if [[ -n "$repo_url" ]]; then
            log_info "Syncing collection: $collection"
            
            # Sync repository
            sync_repository "$repo_url" "$target_path" "${KB_BRANCH_N8N:-main}" "$subpath"
            
            # Generate embeddings
            generate_embeddings "$target_path" "$collection"
            
            # Upload to vector store
            local embeddings_file="$target_path/${collection}_embeddings.json"
            if [[ -f "$embeddings_file" ]]; then
                upload_embeddings "$embeddings_file" "$collection"
            fi
            
        else
            log_warn "Repository URL not configured for collection: $collection"
        fi
    done
}

# Update n8n with new knowledge
update_n8n_knowledge() {
    log_info "Notifying n8n of knowledge base updates..."
    
    # Create a webhook trigger to refresh knowledge in n8n workflows
    if [[ -n "${WEBHOOK_URL:-}" ]]; then
        local webhook_endpoint="$WEBHOOK_URL/webhook/knowledge-sync"
        
        curl -X POST "$webhook_endpoint" \
            -H "Content-Type: application/json" \
            -d "{\"event\": \"knowledge_updated\", \"timestamp\": \"$(date -Iseconds)\"}" \
            > /dev/null 2>&1 || {
            log_warn "Failed to notify n8n of knowledge updates"
        }
    fi
}

# Main synchronization process
main() {
    log_info "Starting knowledge base synchronization"
    
    # Preliminary checks
    check_dependencies
    load_env
    
    # Create knowledge directories
    mkdir -p "$KNOWLEDGE_DIR"/{n8n,videos-e-animacoes,midjourney-prompt}
    
    # Sync all repositories
    sync_all_repositories
    
    # Update n8n
    update_n8n_knowledge
    
    log_info "Knowledge base synchronization completed"
    
    # Generate summary
    log_info "Synchronization Summary:"
    find "$KNOWLEDGE_DIR" -name "*_embeddings.json" -exec basename {} \; | while read file; do
        local collection=$(echo "$file" | sed 's/_embeddings.json//')
        local count=$(jq '. | length' "$KNOWLEDGE_DIR/$collection/$file" 2>/dev/null || echo "0")
        log_info "  - $collection: $count documents"
    done
}

# Run main function
main "$@"