#!/bin/bash
set -euo pipefail

# n8n startup script for Docker container
echo "Starting n8n application..."

# Ensure .n8n directory exists and has proper permissions
mkdir -p /data/.n8n
chmod 755 /data/.n8n

# Create credentials directory if it doesn't exist
mkdir -p /data/.n8n/credentials
chmod 700 /data/.n8n/credentials

# Create workflows directory if it doesn't exist
mkdir -p /data/workflows
chmod 755 /data/workflows

# Create knowledge directory if it doesn't exist  
mkdir -p /data/knowledge
chmod 755 /data/knowledge

# Print database configuration for debugging (without password)
echo "Database configuration:"
echo "  Type: ${DB_TYPE:-not set}"
echo "  Host: ${DB_POSTGRESDB_HOST:-not set}"
echo "  Port: ${DB_POSTGRESDB_PORT:-not set}"
echo "  Database: ${DB_POSTGRESDB_DATABASE:-not set}"
echo "  User: ${DB_POSTGRESDB_USER:-not set}"
echo "  SSL: ${DB_POSTGRESDB_SSL:-false}"

# Print n8n configuration
echo "n8n configuration:"
echo "  Host: ${N8N_HOST:-localhost}"
echo "  Port: ${N8N_PORT:-5678}"
echo "  Protocol: ${N8N_PROTOCOL:-http}"
echo "  User folder: ${N8N_USER_FOLDER:-/data/.n8n}"
echo "  Log level: ${N8N_LOG_LEVEL:-info}"

# Wait a moment for any database to be ready
sleep 2

# Verify n8n is available
echo "Checking n8n installation..."
if ! command -v n8n &> /dev/null; then
    echo "ERROR: n8n command not found in PATH: $PATH"
    echo "Available commands:"
    ls -la /usr/local/bin/ | grep n8n || echo "No n8n found in /usr/local/bin/"
    exit 1
fi

echo "n8n version: $(n8n --version)"

# Start n8n
echo "Starting n8n server..."
exec n8n start
