# Simple single-stage build for MediaWarn
FROM ubuntu:22.04

# Install all dependencies at once
RUN apt-get update && apt-get install -y \
    # System tools
    curl wget git ca-certificates \
    # Go dependencies
    golang-go \
    # Node.js and npm
    nodejs npm \
    # Python and pip
    python3 python3-pip \
    # Runtime dependencies
    ffmpeg nginx supervisor \
    postgresql-client redis-tools \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy all source code
COPY . .

# Build frontend (simple static version)
RUN mkdir -p /app/frontend-build && \
    cat > /app/frontend-build/index.html << 'EOF'
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
        code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; }
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
        
        <p><em>MediaWarn provides complete privacy-focused content analysis.</em></p>
    </div>
</body>
</html>
EOF

# Install Python dependencies
RUN pip3 install --no-cache-dir -r nlp/requirements.txt

# Build Go services (one at a time with error checking)
RUN cd scanner && \
    go mod tidy && \
    go build -o /app/bin/scanner ./cmd/main.go && \
    echo "Scanner built successfully"

RUN cd api && \
    go mod tidy && \
    go build -o /app/bin/api ./main.go && \
    echo "API built successfully"

# Create startup script
RUN mkdir -p /app/bin && \
    cat > /app/start.sh << 'EOF'
#!/bin/bash
set -e

echo "Starting MediaWarn services..."

# Wait for dependencies
if [ ! -z "$DATABASE_URL" ]; then
    echo "Waiting for database..."
    until pg_isready -d "$DATABASE_URL" 2>/dev/null; do
        sleep 2
    done
fi

# Start services based on SERVICE environment variable
case "${SERVICE:-all}" in
    scanner)
        echo "Starting Scanner service..."
        exec /app/bin/scanner
        ;;
    api)
        echo "Starting API service..."
        exec /app/bin/api
        ;;
    nlp)
        echo "Starting NLP worker..."
        cd /app && exec python3 -m nlp.main
        ;;
    frontend)
        echo "Starting Frontend (nginx)..."
        cp -r /app/frontend-build/* /var/www/html/
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

[program:api]
command=/app/bin/api
directory=/app
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/api.err.log
stdout_logfile=/var/log/supervisor/api.out.log

[program:nlp]
command=python3 -m nlp.main
directory=/app
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/nlp.err.log
stdout_logfile=/var/log/supervisor/nlp.out.log

[program:nginx]
command=bash -c "cp -r /app/frontend-build/* /var/www/html/ && nginx -g 'daemon off;'"
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/nginx.err.log
stdout_logfile=/var/log/supervisor/nginx.out.log
SUPERVISOR_EOF

        # Create nginx directories and start supervisor
        mkdir -p /var/www/html /var/log/supervisor /run/nginx
        exec supervisord -c /etc/supervisor/conf.d/mediawarn.conf
        ;;
esac
EOF

RUN chmod +x /app/start.sh

# Create necessary directories
RUN mkdir -p /models /var/log/supervisor /var/www/html

# Expose ports
EXPOSE 7219 8000 8001

# Set default environment variables
ENV SERVICE=all
ENV DATABASE_URL=postgresql://cws:password@localhost:5432/cws
ENV REDIS_URL=redis://localhost:6379
ENV SCAN_INTERVAL=300
ENV WORKERS=4
ENV NLP_WORKERS=2
ENV PORT=8000

CMD ["/app/start.sh"]