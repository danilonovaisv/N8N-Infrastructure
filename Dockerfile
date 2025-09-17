# Multi-stage build for N8N Workflow Documentation API
# Optimized for Hugging Face Spaces deployment

FROM python:3.11-slim as base

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Install system dependencies
RUN apt-get update && apt-get install -y \
    --no-install-recommends \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create app directory and user
RUN groupadd -r appuser && useradd -r -g appuser appuser
WORKDIR /app

# Copy requirements first for better layer caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create necessary directories
RUN mkdir -p database static workflows && \
    chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose port (Hugging Face Spaces uses 7860 by default)
EXPOSE 7860

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:7860/health || exit 1

# Default command
CMD ["python", "app.py"]
