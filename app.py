#!/usr/bin/env python3
"""
🚀 N8N Workflow Documentation Space for Hugging Face
Optimized entry point for Hugging Face Spaces deployment.
"""

import os
import sys
import asyncio
import logging
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
if str(BASE_DIR) not in sys.path:
    sys.path.insert(0, str(BASE_DIR))

# Load environment configuration for Hugging Face Spaces
def load_environment():
    """Load environment variables from .env.hf if it exists."""
    env_file = Path(".env.hf")
    if env_file.exists():
        with open(env_file, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    if key not in os.environ:
                        os.environ[key] = value

# Load environment first
load_environment()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Set environment variables for HF Spaces
os.environ.setdefault("HOST", "0.0.0.0")
os.environ.setdefault("PORT", "7860")  # HF Spaces standard port

# Database configuration - Support both SQLite (local) and PostgreSQL (production)
db_type = os.environ.get("DB_TYPE", "sqlite")
if db_type == "postgresdb":
    # PostgreSQL configuration for Supabase
    os.environ.setdefault("DB_POSTGRESDB_HOST", "aws-1-sa-east-1.pooler.supabase.com")
    os.environ.setdefault("DB_POSTGRESDB_PORT", "6543")
    os.environ.setdefault("DB_POSTGRESDB_DATABASE", "postgres")
    os.environ.setdefault("DB_POSTGRESDB_SSL", "true")
    logger.info("🐘 Using PostgreSQL database configuration")
else:
    # SQLite fallback
    default_db_path = str((BASE_DIR / "database" / "workflows.db").resolve())
    os.environ.setdefault("WORKFLOW_DB_PATH", default_db_path)
    logger.info("📁 Using SQLite database configuration")

def setup_huggingface_environment():
    """Setup directories and environment for HF Spaces."""
    logger.info("🔧 Setting up Hugging Face Spaces environment...")
    
    # Create necessary directories
    directories = {
        "database": BASE_DIR / "database",
        "static": BASE_DIR / "static",
        "workflows": BASE_DIR / "workflows"
    }
    for name, path in directories.items():
        path.mkdir(parents=True, exist_ok=True)
        logger.info(f"✅ Directory created/verified: {name} ({path})")

    os.environ.setdefault("WORKFLOW_SOURCE_DIR", str(directories["workflows"]))
    os.environ.setdefault("STATIC_DIR", str(directories["static"]))
    
    # Initialize database
    try:
        from workflow_db import WorkflowDatabase
        
        # Determine database configuration
        db_type = os.environ.get("DB_TYPE", "sqlite")
        
        if db_type == "postgresdb":
            logger.info("🐘 Connecting to PostgreSQL database...")
            # For PostgreSQL, WorkflowDatabase will use environment variables
            db = WorkflowDatabase()
        else:
            # SQLite configuration
            db_path = BASE_DIR / "database" / "workflows.db"
            logger.info(f"📁 Using SQLite database: {db_path}")
            
            if not Path(db_path).exists() or Path(db_path).stat().st_size == 0:
                logger.info("📚 Initializing SQLite workflows database...")
                db = WorkflowDatabase(str(db_path))
            else:
                db = WorkflowDatabase(str(db_path))
        
        # Check if database needs indexing
        try:
            stats = db.get_stats()
            if stats['total'] == 0:
                logger.info("📚 Database is empty, starting workflow indexing...")
                index_stats = db.index_all_workflows(force_reindex=True)
                logger.info(f"✅ Indexed {index_stats['processed']} workflows")
            else:
                logger.info(f"✅ Database ready: {stats['total']} workflows available")
        except Exception as e:
            logger.warning(f"⚠️  Database indexing partially failed: {e}")
            logger.info("📝 Database will be initialized on first API call...")
            
    except Exception as e:
        logger.error(f"❌ Database setup error: {e}")
        # Continue anyway - the API will handle missing data gracefully

def create_static_files():
    """Create basic static files for the web interface."""
    static_dir = BASE_DIR / "static"
    static_dir.mkdir(exist_ok=True)
    
    index_html = static_dir / "index.html"
    if not index_html.exists():
        logger.info("📄 Creating basic HTML interface...")
        html_content = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>N8N Workflows Documentation</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 1200px; margin: 0 auto; padding: 20px; }
        .header { text-align: center; margin-bottom: 30px; }
        .api-link { display: inline-block; margin: 10px; padding: 15px 25px; 
                   background: #0066cc; color: white; text-decoration: none; border-radius: 5px; }
        .api-link:hover { background: #0052a3; }
        .description { background: #f5f5f5; padding: 20px; border-radius: 8px; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🚀 N8N Workflows Documentation API</h1>
        <p>Advanced search engine for N8N workflow automation</p>
    </div>
    
    <div class="description">
        <h2>Available Endpoints:</h2>
        <a href="/api/workflows" class="api-link">📊 Browse Workflows</a>
        <a href="/api/stats" class="api-link">📈 Statistics</a>
        <a href="/docs" class="api-link">📚 API Documentation</a>
        <a href="/health" class="api-link">❤️ Health Check</a>
    </div>
    
    <div class="description">
        <h3>Features:</h3>
        <ul>
            <li>🔍 Advanced workflow search and filtering</li>
            <li>📋 Comprehensive workflow metadata</li>
            <li>🏷️ Category-based organization</li>
            <li>⚡ High-performance FastAPI backend</li>
            <li>🤖 AI-powered workflow analysis</li>
        </ul>
    </div>
    
    <div style="text-align: center; margin-top: 40px; color: #666;">
        <p>Powered by <strong>FastAPI</strong> • Hosted on <strong>Hugging Face Spaces</strong></p>
    </div>
</body>
</html>"""
        index_html.write_text(html_content)
        logger.info("✅ Basic HTML interface created")

async def startup_tasks():
    """Perform startup tasks asynchronously."""
    try:
        setup_huggingface_environment()
        create_static_files()
        logger.info("🎉 Hugging Face Spaces setup completed successfully!")
    except Exception as e:
        logger.error(f"❌ Startup error: {e}")
        # Don't fail completely, let the app start anyway

def main():
    """Main entry point for Hugging Face Spaces."""
    logger.info("🚀 Starting N8N Workflow Documentation API on Hugging Face Spaces...")
    
    # Run startup tasks
    asyncio.run(startup_tasks())
    
    # Import and start the FastAPI app
    try:
        from api_server import app
        import uvicorn
        
        # Get configuration from environment
        host = os.getenv("HOST", "0.0.0.0")
        port = int(os.getenv("PORT", "7860"))
        
        logger.info(f"🌐 Server starting on {host}:{port}")
        logger.info("📊 API Documentation will be available at /docs")
        
        # Start the server
        uvicorn.run(
            app,
            host=host,
            port=port,
            log_level="info",
            access_log=True
        )
        
    except ImportError as e:
        logger.error(f"❌ Failed to import required modules: {e}")
        sys.exit(1)
    except Exception as e:
        logger.error(f"❌ Failed to start server: {e}")
        sys.exit(1)

# For Hugging Face Spaces compatibility
if __name__ == "__main__":
    main()

# Also expose the app directly for gunicorn/uvicorn
try:
    # Ensure environment is set up
    asyncio.run(startup_tasks())
    from api_server import app
except Exception as e:
    logger.warning(f"⚠️  Could not set up environment during import: {e}")
    # Create a minimal fallback app
    from fastapi import FastAPI
    app = FastAPI(title="N8N Workflows API - Setup Required")
    
    @app.get("/")
    async def root():
        return {"message": "N8N Workflows API - Setup in progress", "status": "initializing"}
    
    @app.get("/health")
    async def health():
        return {"status": "starting"}
