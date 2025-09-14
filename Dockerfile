# Use the official n8n image, pinning a specific version for stability.
# This image is already optimized, secure (runs as non-root), and includes healthchecks.
FROM n8nio/n8n:1.53.1

# Hugging Face Spaces automatically sets the PORT environment variable.
# n8n will listen on this port by default. No ARG/ENV for PORT is needed.

# Set environment variables that are safe and necessary for the build.
# All sensitive data (DB credentials, API keys) should be set as secrets
# in the Hugging Face Space repository settings.

# --- Production-Ready Settings ---

# For detailed execution logs for debugging failed runs
ENV EXECUTIONS_DATA_SAVE_ON_ERROR=all
# Save resources by not storing data for successful runs
ENV EXECUTIONS_DATA_SAVE_ON_SUCCESS=none
# Enable automatic cleanup of old execution data
ENV EXECUTIONS_DATA_PRUNE=true
# Keep execution data for 14 days (336 hours)
ENV EXECUTIONS_DATA_MAX_AGE=336

# Enable Prometheus metrics endpoint
ENV N8N_METRICS=true

# The official n8n image already includes a HEALTHCHECK.
# The default is sufficient and correctly configured.
