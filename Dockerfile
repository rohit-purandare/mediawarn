# Multi-stage build for MediaWarn unified package
FROM node:18-alpine AS frontend-builder

WORKDIR /app/frontend

# Create a simple static frontend as fallback
RUN mkdir -p build && \
    cat > build/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>MediaWarn - Content Warning Scanner</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #333; margin-bottom: 20px; }
        .status { padding: 15px; margin: 20px 0; border-radius: 4px; }
        .info { background: #e7f3ff; border-left: 4px solid #2196F3; }
        .api-link { color: #2196F3; text-decoration: none; }
        .api-link:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🛡️ MediaWarn</h1>
        <p>Privacy-focused content warning scanner for media files</p>
        
        <div class="status info">
            <strong>Service Status:</strong> MediaWarn backend services are running
        </div>
        
        <h2>API Access</h2>
        <p>Access the REST API at: <a href="/api" class="api-link">http://localhost:8000/api</a></p>
        
        <h2>Available Endpoints</h2>
        <ul>
            <li><code>GET /api/scan/status</code> - Get current scan status</li>
            <li><code>POST /api/scan/start</code> - Start scanning</li>
            <li><code>GET /api/results</code> - List scan results</li>
            <li><code>GET /api/stats/overview</code> - Get overview statistics</li>
        </ul>
        
        <h2>Setup</h2>
        <ol>
            <li>Configure your media directories in the Docker compose file</li>
            <li>Start scanning via the API</li>
            <li>Monitor results through the API endpoints</li>
        </ol>
        
        <p><em>Full React frontend coming soon. API is fully functional.</em></p>
    </div>
</body>
</html>
EOF

FROM golang:1.21-alpine AS go-builder

RUN apk add --no-cache git

# Set up workspace
WORKDIR /app

# Copy all Go modules and source
COPY scanner/ ./scanner/
COPY api/ ./api/

# Build Scanner Service
WORKDIR /app/scanner
RUN go mod download && go mod tidy && \
    CGO_ENABLED=0 GOOS=linux go build -v -o scanner ./cmd/main.go

# Build API Service  
WORKDIR /app/api
RUN go mod download && go mod tidy && \
    CGO_ENABLED=0 GOOS=linux go build -v -o api ./main.go

FROM python:3.11-slim AS final

# Install system dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    nginx \
    supervisor \
    ca-certificates \
    postgresql-client \
    redis-tools \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Install Python dependencies
COPY nlp/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy built Go binaries
COPY --from=go-builder /app/scanner/scanner ./bin/scanner
COPY --from=go-builder /app/api/api ./bin/api

# Copy Python NLP service
COPY nlp/app/ ./nlp/

# Copy built frontend
COPY --from=frontend-builder /app/frontend/build ./frontend/
COPY frontend/nginx.conf /etc/nginx/sites-available/default

# Copy configuration files
COPY config/ ./config/
COPY init.sql ./

# Create necessary directories
RUN mkdir -p /models /var/log/supervisor /run/nginx

# Create startup script
RUN cat > /app/start.sh << 'EOF'
#!/bin/bash
set -e

# Wait for dependencies if DATABASE_URL and REDIS_URL are provided
if [ ! -z "$DATABASE_URL" ]; then
    echo "Waiting for database connection..."
    until pg_isready -d "$DATABASE_URL" 2>/dev/null || [ $? -eq 2 ]; do
        echo "Database not ready, waiting..."
        sleep 2
    done
    echo "Database is ready"
fi

# Start services based on SERVICE environment variable
case "${SERVICE:-all}" in
    scanner)
        echo "Starting Scanner service..."
        exec ./bin/scanner
        ;;
    api)
        echo "Starting API service..."
        exec ./bin/api
        ;;
    nlp)
        echo "Starting NLP worker..."
        exec python -m nlp.main
        ;;
    frontend)
        echo "Starting Frontend (nginx)..."
        exec nginx -g "daemon off;"
        ;;
    all|*)
        echo "Starting all services with supervisor..."
        # Configure supervisor
        cat > /etc/supervisor/conf.d/mediawarn.conf << 'SUPERVISOR_EOF'
[supervisord]
nodaemon=true
user=root
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid

[program:scanner]
command=/app/bin/scanner
directory=/app
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/scanner.err.log
stdout_logfile=/var/log/supervisor/scanner.out.log
user=root

[program:api]
command=/app/bin/api
directory=/app
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/api.err.log
stdout_logfile=/var/log/supervisor/api.out.log
user=root

[program:nlp]
command=python -m nlp.main
directory=/app
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/nlp.err.log
stdout_logfile=/var/log/supervisor/nlp.out.log
user=root

[program:nginx]
command=nginx -g "daemon off;"
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/nginx.err.log
stdout_logfile=/var/log/supervisor/nginx.out.log
user=root
SUPERVISOR_EOF
        exec /usr/bin/supervisord -c /etc/supervisor/conf.d/mediawarn.conf
        ;;
esac
EOF

RUN chmod +x /app/start.sh

# Expose ports
EXPOSE 7219 8000 8001

# Set environment variables with defaults
ENV SERVICE=all
ENV DATABASE_URL=postgresql://cws:password@localhost:5432/cws
ENV REDIS_URL=redis://localhost:6379
ENV SCAN_INTERVAL=300
ENV WORKERS=4
ENV NLP_WORKERS=2
ENV PORT=8000
ENV REACT_APP_API_URL=http://localhost:8000

CMD ["/app/start.sh"]