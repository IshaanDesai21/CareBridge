# CareBridge Backend

## Overview
Backend services for the CareBridge platform, providing RESTful APIs for the iOS app and web dashboard.

## Setup

### Prerequisites
- Python 3.11+
- PostgreSQL 14+
- Redis 7+

### Installation
```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Set up environment variables
cp .env.example .env
# Edit .env with your configuration

# Run migrations
python manage.py migrate

# Start development server
python manage.py runserver
```

## API Documentation
API documentation is available at `/api/docs` when running the server.

## Testing
```bash
pytest
```

## Project Structure
```
backend/
├── api/           # API endpoints
├── models/        # Database models
├── services/      # Business logic
├── utils/         # Utility functions
└── tests/         # Test suite
```

## Related Documentation
- [API Documentation](../docs/api.md)
- [Database Schema](../docs/database.md)
