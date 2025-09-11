# Multi-stage build for MediaWarn unified package
FROM node:18-alpine AS frontend-builder

# Install python and build dependencies for native modules
RUN apk add --no-cache python3 make g++

WORKDIR /app/frontend
COPY frontend/package*.json ./

# Clear npm cache and install with more verbose output
RUN npm cache clean --force && \
    npm install --verbose --no-optional && \
    npm list --depth=0

COPY frontend/ ./
RUN npm run build

FROM golang:1.21-alpine AS go-builder

RUN apk add --no-cache git

# Build Scanner Service
WORKDIR /app/scanner
COPY scanner/go.mod ./
RUN go mod download && go mod verify
COPY scanner/ ./
RUN CGO_ENABLED=0 GOOS=linux go build -o scanner ./cmd/main.go

# Build API Service
WORKDIR /app/api
COPY api/go.mod ./
RUN go mod download && go mod verify
COPY api/ ./
RUN CGO_ENABLED=0 GOOS=linux go build -o api .

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