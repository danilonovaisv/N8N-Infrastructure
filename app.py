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

# Database configuration - Auto-detect production environment and use PostgreSQL
# In Hugging Face Spaces, prioritize PostgreSQL if available
db_type = os.environ.get("DB_TYPE")

# Auto-detect if we're in production (HF Spaces) and should use PostgreSQL
if not db_type:
    # Check for production environment indicators
    is_production = (
        os.environ.get("SPACE_ID") or 
        os.environ.get("SPACES_BUILDKIT_VERSION") or 
        os.path.exists("/.dockerenv") or
        os.environ.get("RAILWAY_PROJECT_ID") or
        os.environ.get("RENDER_SERVICE_ID")
    )
    
    if is_production:
        # Check if filesystem is writable
        try:
            test_path = Path("./test_write.tmp")
            test_path.touch()
            test_path.unlink()
            filesystem_writable = True
        except (PermissionError, OSError):
            filesystem_writable = False
            
        if not filesystem_writable:
            logger.info("🔒 Detected read-only filesystem - will use temporary storage")
            
        # Prefer PostgreSQL in production if credentials might be available
        db_type = "postgresdb"
        logger.info("🐘 Auto-detected production environment - attempting PostgreSQL")
    else:
        db_type = "sqlite"
        logger.info("📁 Auto-detected local environment - using SQLite")

if db_type == "postgresdb":
    # PostgreSQL configuration for Supabase
    os.environ.setdefault("DB_POSTGRESDB_HOST", "aws-1-sa-east-1.pooler.supabase.com")
    os.environ.setdefault("DB_POSTGRESDB_PORT", "6543")
    os.environ.setdefault("DB_POSTGRESDB_DATABASE", "postgres")
    os.environ.setdefault("DB_POSTGRESDB_SSL", "true")
    logger.info("🐘 Using PostgreSQL database configuration")
else:
    # SQLite fallback
    os.environ.setdefault("WORKFLOW_DB_PATH", "database/workflows.db")
    logger.info("📁 Using SQLite database configuration")
    logger.info("📁 Using SQLite database configuration")

def setup_huggingface_environment():
    """Setup directories and environment for HF Spaces."""
    logger.info("🔧 Setting up Hugging Face Spaces environment...")
    
    # Create necessary directories with error handling
    directory_paths = {
        "database": Path("database"),
        "static": Path("static"),
        "workflows": Path("workflows")
    }
    
    for name, path in directory_paths.items():
        try:
            path.mkdir(exist_ok=True, parents=True, mode=0o755)
            logger.info(f"✅ Directory created/verified: {name} ({path.absolute()})")
        except (PermissionError, OSError) as e:
            logger.warning(f"⚠️  Could not create {name} directory ({e}) - using fallback")
            if name == "database":
                # Force temp database location
                os.environ["WORKFLOW_DB_PATH"] = "/tmp/workflows.db"
                logger.info(f"🔁 Database will use temp location: /tmp/workflows.db")
            elif name == "static":
                # Static files will be served from memory
                logger.info("📝 Static files will be served from memory")
            elif name == "workflows":
                # Workflows directory fallback
                logger.info("📝 Workflows will be loaded from embedded sources if available")

    os.environ.setdefault("WORKFLOW_SOURCE_DIR", str(directory_paths["workflows"]))
    os.environ.setdefault("STATIC_DIR", str(directory_paths["static"]))
    
    # Initialize database
    try:
        from workflow_db import WorkflowDatabase
        
        # Determine database configuration
        db_type = os.environ.get("DB_TYPE", "sqlite")
        
        if db_type == "postgresdb":
            # Note: Current WorkflowDatabase only supports SQLite
            # PostgreSQL support would need to be implemented in WorkflowDatabase class
            logger.warning("⚠️  PostgreSQL requested but WorkflowDatabase only supports SQLite")
            logger.info("🔁 Falling back to SQLite (PostgreSQL support not implemented)...")
            db_type = "sqlite"
            os.environ["DB_TYPE"] = "sqlite"
        
        if db_type == "sqlite":
            # Try local database first, fall back to temp if read-only filesystem
            try:
                db_path = BASE_DIR / "database" / "workflows.db"
                logger.info(f"📁 Attempting to use SQLite database: {db_path}")
                
                # Test if we can write to the database directory
                test_file = db_path.parent / "test_write.tmp"
                test_file.touch()
                test_file.unlink()
                
                # If we get here, we can write to the directory
                if not Path(db_path).exists() or Path(db_path).stat().st_size == 0:
                    logger.info("📚 Initializing SQLite workflows database...")
                    db = WorkflowDatabase(str(db_path))
                else:
                    db = WorkflowDatabase(str(db_path))
                    
            except (PermissionError, OSError) as e:
                logger.warning(f"⚠️  Cannot write to local database directory: {e}")
                logger.info("🔁 Using temporary database location...")
                temp_db_path = "/tmp/workflows.db"
                os.environ["WORKFLOW_DB_PATH"] = temp_db_path
                logger.info(f"📁 Using temporary SQLite database: {temp_db_path}")
                db = WorkflowDatabase(temp_db_path)
        
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
        # Final fallback - try temp database
        try:
            logger.info("🔁 Attempting final fallback to temporary database...")
            temp_db_path = "/tmp/fallback_workflows.db"
            os.environ["DB_TYPE"] = "sqlite"
            os.environ["WORKFLOW_DB_PATH"] = temp_db_path
            from workflow_db import WorkflowDatabase
            db = WorkflowDatabase(temp_db_path)
            logger.info(f"✅ Emergency fallback database created: {temp_db_path}")
        except Exception as fallback_error:
            logger.warning(f"⚠️  All database options failed: {fallback_error}")
            logger.info("📝 API will start without pre-initialized database")
            logger.info("🔄 Database initialization will be attempted on first API request")
            # Create a minimal environment setup so the API can still start
            os.environ["DB_TYPE"] = "sqlite"
            os.environ["WORKFLOW_DB_PATH"] = "/tmp/delayed_init_workflows.db"

def create_static_files():
    """Create basic static files for the web interface."""
    try:
        static_dir = Path("static")
        static_dir.mkdir(exist_ok=True, mode=0o755)
        
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
        try:
            index_html.write_text(html_content)
            logger.info("✅ Basic HTML interface created")
        except PermissionError:
            logger.warning("⚠️  Could not create static HTML file - will serve from memory")
    except Exception as e:
        logger.warning(f"⚠️  Static file setup failed: {e} - will serve basic content from API")

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
