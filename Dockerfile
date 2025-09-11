# Minimal MediaWarn package - Python NLP service + Frontend
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    # System tools
    curl wget git ca-certificates \
    # Go dependencies
    golang-go \
    # Python and pip
    python3 python3-pip \
    # Runtime dependencies
    ffmpeg nginx supervisor \
    postgresql-client redis-tools \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy source code
COPY nlp/ ./nlp/
COPY config/ ./config/
COPY scanner/ ./scanner/
COPY api/ ./api/

# Install Python dependencies
RUN pip3 install --no-cache-dir -r nlp/requirements.txt

# Build Go services with error handling
RUN echo "Building Go services..." && \
    go version && \
    (cd scanner && go mod tidy && go build -o ../bin/scanner ./cmd/main.go && echo "✅ Scanner built") && \
    (cd api && go mod tidy && go build -o ../bin/api ./main.go && echo "✅ API built") && \
    mkdir -p bin

# Build static frontend
RUN mkdir -p /app/frontend-build && \
    cat > /app/frontend-build/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>MediaWarn - Content Warning Scanner</title>
    <style>
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; 
            margin: 0; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .container { 
            max-width: 900px; 
            margin: 20px;
            background: white; 
            padding: 40px; 
            border-radius: 16px; 
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
        }
        h1 { 
            color: #333; 
            margin-bottom: 10px; 
            font-size: 2.5em;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }
        .subtitle {
            color: #666;
            margin-bottom: 30px;
            font-size: 1.2em;
        }
        .status { 
            padding: 20px; 
            margin: 30px 0; 
            border-radius: 8px; 
            border-left: 5px solid #4CAF50;
        }
        .info { 
            background: #f0f8ff; 
            border-left-color: #2196F3; 
        }
        .warning {
            background: #fff8e1;
            border-left-color: #ff9800;
        }
        .api-link { 
            color: #2196F3; 
            text-decoration: none; 
            font-weight: 500;
        }
        .api-link:hover { 
            text-decoration: underline; 
        }
        code { 
            background: #f8f9fa; 
            padding: 4px 8px; 
            border-radius: 4px; 
            font-family: 'Monaco', 'Menlo', monospace;
            font-size: 0.9em;
        }
        .endpoint-list {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
            margin: 20px 0;
        }
        .endpoint-list ul {
            margin: 0;
            padding-left: 20px;
        }
        .endpoint-list li {
            margin: 8px 0;
        }
        .setup-steps {
            background: #f0f8ff;
            padding: 20px;
            border-radius: 8px;
            border-left: 4px solid #2196F3;
        }
        .setup-steps ol {
            margin: 10px 0;
            padding-left: 20px;
        }
        .setup-steps li {
            margin: 10px 0;
            line-height: 1.6;
        }
        .footer {
            text-align: center;
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #eee;
            color: #666;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🛡️ MediaWarn</h1>
        <p class="subtitle">Privacy-focused content warning scanner for media files</p>
        
        <div class="status info">
            <strong>🟢 Service Status:</strong> All MediaWarn services are running<br>
            <small>Scanner, API, NLP, and Frontend services active</small>
        </div>
        
        <h2>🔗 Available Services</h2>
        <div class="endpoint-list">
            <ul>
                <li><strong>Scanner Service:</strong> Media file discovery and processing</li>
                <li><strong>API Service:</strong> REST API on port 8000 - <a href="http://localhost:8000/api" class="api-link">http://localhost:8000/api</a></li>
                <li><strong>NLP Processing:</strong> Content analysis engine on port 8001</li>
                <li><strong>Web Interface:</strong> This status page on port 7219</li>
            </ul>
        </div>
        
        <h2>⚙️ Configuration</h2>
        <div class="setup-steps">
            <strong>Environment Variables:</strong>
            <ul>
                <li><code>DATABASE_URL</code> - PostgreSQL connection string</li>
                <li><code>REDIS_URL</code> - Redis connection string</li>
                <li><code>NLP_WORKERS</code> - Number of NLP worker processes (default: 2)</li>
                <li><code>MODEL_CACHE</code> - Directory for ML model cache</li>
            </ul>
        </div>
        
        <h2>🚀 Quick Start</h2>
        <div class="setup-steps">
            <ol>
                <li>Configure your database and Redis connections</li>
                <li>Mount your media directories in the Docker container</li>
                <li>Start the container: <code>docker run -d -p 7219:7219 -p 8001:8001 mediawarn</code></li>
                <li>Access this interface at <a href="http://localhost:7219" class="api-link">http://localhost:7219</a></li>
            </ol>
        </div>

        <h2>📋 Service Modes</h2>
        <div class="endpoint-list">
            <p>Set the <code>SERVICE</code> environment variable:</p>
            <ul>
                <li><code>nlp</code> - Run NLP processing service only</li>
                <li><code>frontend</code> - Run web interface only</li>
                <li><code>all</code> - Run all available services (default)</li>
            </ul>
        </div>
        
        <div class="footer">
            <p><strong>MediaWarn</strong> - Complete privacy protection with local processing</p>
            <p><em>Version 1.0 - Minimal NLP Service Package</em></p>
        </div>
    </div>
</body>
</html>
EOF

# Create startup script
RUN cat > /app/start.sh << 'EOF'
#!/bin/bash
set -e

echo "Starting MediaWarn Minimal Services..."

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
        echo "Starting all MediaWarn services with supervisor..."
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

        # Create directories and start supervisor
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
ENV NLP_WORKERS=2
ENV MODEL_CACHE=/models

CMD ["/app/start.sh"]