# N8N Workflow Documentation API for Hugging Face Spaces
# Optimized Docker build with proper user management

FROM python:3.11-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Install system dependencies including wget for health checks
RUN apt-get update && apt-get install -y \
    --no-install-recommends \
    build-essential \
    curl \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user first
RUN groupadd -r appuser && useradd -r -g appuser -m appuser

# Set working directory and create it with proper ownership
RUN mkdir -p /app && chown appuser:appuser /app
WORKDIR /app

# Copy requirements first for better layer caching
COPY requirements.txt .

# Install Python dependencies as root (to avoid pip warning in production)
RUN python -m pip install --no-cache-dir --upgrade pip && \
    python -m pip install --no-cache-dir -r requirements.txt

# Switch to non-root user before copying files
USER appuser

# Copy application code as the appuser
COPY --chown=appuser:appuser . .

# Create necessary directories as the appuser
RUN mkdir -p database static workflows

# Expose port 7860 (Hugging Face Spaces standard)
EXPOSE 7860

# Health check using curl
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:7860/health || exit 1

# Start the application
CMD ["python", "app.py"]
