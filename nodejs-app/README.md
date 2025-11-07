# Node.js GitOps Application

A RESTful API application built with Express.js, MySQL, and Redis for demonstrating GitOps deployment patterns.

## Features

- **Express.js** REST API server
- **MySQL** for persistent data storage
- **Redis** for caching with automatic cache invalidation
- **Health checks** for Kubernetes liveness and readiness probes
- **Graceful shutdown** handling
- **Docker** containerization
- **Production-ready** error handling and logging

## Architecture

```
Client Request
    ↓
Express Server
    ↓
Cache Middleware (Redis)
    ↓ (cache miss)
MySQL Database
    ↓
Cache Update (Redis)
    ↓
Response to Client
```

## API Endpoints

### Health Checks

- `GET /health` - Application health status (MySQL + Redis)
- `GET /ready` - Readiness probe (MySQL connection)
- `GET /live` - Liveness probe (application running)

### Items API

- `GET /api/items` - List all items (cached)
- `GET /api/items/:id` - Get item by ID (cached)
- `POST /api/items` - Create new item
- `PUT /api/items/:id` - Update item
- `DELETE /api/items/:id` - Delete item

## Environment Variables

```bash
# MySQL Configuration
DB_HOST=localhost
DB_PORT=3306
DB_NAME=appdb
DB_USER=admin
DB_PASSWORD=your_password

# Redis Configuration
REDIS_HOST=localhost
REDIS_PORT=6379

# Application
PORT=3000
NODE_ENV=production
```

## Local Development

### Prerequisites

- Node.js 18+
- MySQL 8.0+
- Redis 7.0+

### Installation

```bash
# Install dependencies
npm install

# Start development server
npm run dev

# Start production server
npm start
```

### Testing with curl

```bash
# Health check
curl http://localhost:3000/health

# List items
curl http://localhost:3000/api/items

# Get item by ID
curl http://localhost:3000/api/items/1

# Create item
curl -X POST http://localhost:3000/api/items \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Item","description":"Test Description"}'

# Update item
curl -X PUT http://localhost:3000/api/items/1 \
  -H "Content-Type: application/json" \
  -d '{"name":"Updated Item","description":"Updated Description"}'

# Delete item
curl -X DELETE http://localhost:3000/api/items/1
```

## Docker

### Build Image

```bash
docker build -t nodejs-app:latest .
```

### Run Container

```bash
docker run -d \
  -p 3000:3000 \
  -e DB_HOST=your-rds-endpoint \
  -e DB_PORT=3306 \
  -e DB_NAME=appdb \
  -e DB_USER=admin \
  -e DB_PASSWORD=your_password \
  -e REDIS_HOST=your-redis-endpoint \
  -e REDIS_PORT=6379 \
  --name nodejs-app \
  nodejs-app:latest
```

## Caching Strategy

### Cache Keys

- `items:all` - List of all items (TTL: 5 minutes)
- `item:<id>` - Individual item (TTL: 5 minutes)

### Cache Invalidation

- Creating an item → Invalidates `items:all`
- Updating an item → Invalidates `item:<id>` and `items:all`
- Deleting an item → Invalidates `item:<id>` and `items:all`

### Cache Behavior

- **Cache Hit**: Response includes `"cached": true` and is served in ~1-5ms
- **Cache Miss**: Response includes `"cached": false` and is served in ~50-100ms

## Database Schema

```sql
CREATE TABLE items (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_name (name)
);
```

## Error Handling

- **MySQL Connection Failure**: Returns 503, application will restart
- **Redis Connection Failure**: Logs warning, continues without caching
- **Invalid Input**: Returns 400 with error message
- **Not Found**: Returns 404
- **Server Error**: Returns 500 with error message

## Kubernetes Deployment

The application is designed to run in Kubernetes with:

- **Liveness Probe**: `GET /live`
- **Readiness Probe**: `GET /ready`
- **Environment Variables**: Injected from Kubernetes Secrets
- **Graceful Shutdown**: Handles SIGTERM/SIGINT signals
- **Non-root User**: Runs as user ID 1001 for security

## Performance

- **Without Cache**: ~50-100ms per request
- **With Cache**: ~1-5ms per request
- **Cache Hit Rate**: Typically 80-90% for read-heavy workloads
- **Database Load Reduction**: 80-90% fewer queries

## Monitoring

The application logs:
- Request method, path, status code, and duration
- Cache hits and misses
- Database connection status
- Redis connection status
- Errors and warnings

## License

MIT
