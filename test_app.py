#!/usr/bin/env python3
"""
Simple test script to verify the app works correctly
"""

import os
import sys
import asyncio
from pathlib import Path

# Add the current directory to path
sys.path.insert(0, str(Path(__file__).parent))

def test_imports():
    """Test that all required modules can be imported."""
    print("🧪 Testing imports...")
    
    try:
        import fastapi
        print("✅ FastAPI imported successfully")
    except ImportError as e:
        print(f"❌ FastAPI import failed: {e}")
        return False
        
    try:
        import uvicorn
        print("✅ Uvicorn imported successfully")
    except ImportError as e:
        print(f"❌ Uvicorn import failed: {e}")
        return False
        
    try:
        import pydantic
        print("✅ Pydantic imported successfully")
    except ImportError as e:
        print(f"❌ Pydantic import failed: {e}")
        return False
        
    try:
        # Test PostgreSQL drivers
        import psycopg2
        print("✅ PostgreSQL driver (psycopg2) imported successfully")
    except ImportError as e:
        print(f"⚠️  PostgreSQL driver (psycopg2) not available: {e}")
        
    try:
        import asyncpg
        print("✅ Async PostgreSQL driver (asyncpg) imported successfully")
    except ImportError as e:
        print(f"⚠️  Async PostgreSQL driver (asyncpg) not available: {e}")
        
    return True

def test_app_creation():
    """Test that the app can be created without errors."""
    print("\n🧪 Testing app creation...")
    
    try:
        # Set test environment
        os.environ["DB_TYPE"] = "sqlite"
        os.environ["WORKFLOW_DB_PATH"] = "test_database.db"
        
        # Import the app
        from app import load_environment
        load_environment()
        print("✅ Environment loading works")
        
        # Try to import the api_server
        from api_server import app
        print("✅ FastAPI app created successfully")
        
        return True
    except Exception as e:
        print(f"❌ App creation failed: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_database():
    """Test database connectivity."""
    print("\n🧪 Testing database...")
    
    try:
        from workflow_db import WorkflowDatabase
        
        # Test SQLite (should always work)
        db = WorkflowDatabase("test_workflows.db")
        print("✅ SQLite database connection works")
        
        # Clean up
        test_db = Path("test_workflows.db")
        if test_db.exists():
            test_db.unlink()
            
        return True
    except Exception as e:
        print(f"❌ Database test failed: {e}")
        return False

async def test_startup():
    """Test the startup tasks."""
    print("\n🧪 Testing startup tasks...")
    
    try:
        from app import startup_tasks
        await startup_tasks()
        print("✅ Startup tasks completed successfully")
        return True
    except Exception as e:
        print(f"❌ Startup tasks failed: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    """Run all tests."""
    print("🚀 N8N Workflow API - Testing Suite")
    print("=" * 50)
    
    tests = [
        ("Import Tests", test_imports),
        ("App Creation", test_app_creation),
        ("Database Tests", test_database),
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        print(f"\n📋 Running {test_name}...")
        try:
            if test_func():
                passed += 1
                print(f"✅ {test_name} PASSED")
            else:
                print(f"❌ {test_name} FAILED")
        except Exception as e:
            print(f"❌ {test_name} FAILED with exception: {e}")
    
    # Test async startup
    print(f"\n📋 Running Startup Tests...")
    try:
        if asyncio.run(test_startup()):
            passed += 1
            print(f"✅ Startup Tests PASSED")
        else:
            print(f"❌ Startup Tests FAILED")
        total += 1
    except Exception as e:
        print(f"❌ Startup Tests FAILED with exception: {e}")
        total += 1
    
    print("\n" + "=" * 50)
    print(f"📊 Test Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All tests passed! The app is ready for deployment.")
        return True
    else:
        print("⚠️  Some tests failed. Check the output above.")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)