---
title: N8N Workflows Documentation API
emoji: 🚀
colorFrom: blue
colorTo: purple
sdk: docker
app_port: 7860
pinned: false
license: mit
tags:
  - automation
  - n8n
  - workflows
  - documentation
  - api
  - fastapi
---

# 🚀 N8N Workflows Documentation API

Advanced search engine and documentation system for N8N workflow automation. This Hugging Face Space provides a powerful FastAPI-based interface to browse, search, and analyze thousands of N8N workflow templates.

## ✨ Features

- **🔍 Advanced Search**: Intelligent search across workflow names, descriptions, and metadata
- **📊 Rich Filtering**: Filter by trigger type, complexity, active status, and more  
- **📋 Comprehensive Metadata**: Detailed workflow information including node counts, integrations, and tags
- **⚡ High Performance**: Optimized SQLite database with sub-100ms response times
- **🏷️ Smart Categorization**: AI-powered workflow categorization and organization
- **📈 Analytics**: Detailed statistics and insights about workflow patterns
- **🔗 RESTful API**: Clean, well-documented API endpoints for integration

## 🌐 API Endpoints

### Main Endpoints
- **`GET /`** - Interactive web interface
- **`GET /health`** - Health check endpoint
- **`GET /docs`** - Interactive API documentation (Swagger UI)

### Core API
- **`GET /api/workflows`** - Search and browse workflows with pagination
- **`GET /api/workflows/{filename}`** - Get detailed workflow information
- **`GET /api/stats`** - Get database statistics and insights

### Search Parameters
- `q`: Search query string
- `trigger`: Filter by trigger type (webhook, schedule, manual, etc.)
- `complexity`: Filter by complexity level (low, medium, high)
- `active_only`: Show only active workflows
- `page`: Page number for pagination
- `per_page`: Items per page (1-100)

## 🚀 Quick Start

The API is ready to use! No setup required.

### Example API Calls

```bash
# Get all workflows
curl "https://your-space-url.hf.space/api/workflows"

# Search for specific workflows
curl "https://your-space-url.hf.space/api/workflows?q=webhook&trigger=webhook"

# Get statistics
curl "https://your-space-url.hf.space/api/stats"

# Health check
curl "https://your-space-url.hf.space/health"
```

### Python Example

```python
import requests

# Base URL of your Space
BASE_URL = "https://your-space-url.hf.space"

# Search for workflows
response = requests.get(f"{BASE_URL}/api/workflows", params={
    "q": "automation",
    "trigger": "webhook", 
    "per_page": 10
})

workflows = response.json()
print(f"Found {workflows['total']} workflows")
```

## 📊 What's Inside

This Space contains a comprehensive database of N8N workflows featuring:

- **2000+** Workflow templates
- **Multiple Categories**: E-commerce, CRM, Social Media, Data Processing, and more
- **Rich Metadata**: Node counts, complexity analysis, integration mapping
- **Smart Indexing**: Optimized for fast search and retrieval
- **Real-time Stats**: Up-to-date analytics and insights

## 🔧 Technical Stack

- **FastAPI**: High-performance Python web framework
- **SQLite**: Lightweight, optimized database
- **Pydantic**: Data validation and serialization  
- **Uvicorn**: ASGI server for production deployment
- **Docker**: Containerized deployment

## 📈 Performance

- **Sub-100ms** response times for most queries
- **Efficient Pagination**: Handles large result sets gracefully
- **Smart Caching**: Optimized database queries
- **Concurrent Requests**: Supports multiple simultaneous users

## 🔒 API Rate Limits

This Space is configured for fair usage:
- No authentication required for basic usage
- Rate limiting may apply for excessive requests
- Use pagination for large datasets

## 💡 Use Cases

- **Workflow Discovery**: Find templates for your automation needs
- **Learning Resource**: Explore best practices and patterns
- **Integration**: Build apps that leverage N8N workflow data
- **Analytics**: Analyze workflow trends and patterns
- **Documentation**: Comprehensive workflow documentation system

## 🤝 Contributing

This project is part of the N8N Infrastructure ecosystem. Contributions welcome!

## 📄 License

MIT License - Feel free to use this API in your projects.

---

**Powered by Hugging Face Spaces** | **Built with FastAPI** | **N8N Infrastructure Project**