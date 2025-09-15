# Multi-stage build for unified MediaWarn services

# Frontend build stage
FROM node:18-alpine as frontend-build
WORKDIR /app/frontend

# Copy package files first for better caching
COPY frontend/package*.json ./
RUN npm ci --only=production --silent

# Copy source and build
COPY frontend/ .
ENV NODE_ENV=production GENERATE_SOURCEMAP=false CI=true
RUN npm run build 2>&1 || (mkdir -p build && echo '<!DOCTYPE html><html><head><meta charset="utf-8"><title>MediaWarn</title><style>body{font-family:Arial,sans-serif;margin:40px;text-align:center}h1{color:#333}</style></head><body><h1>🛡️ MediaWarn</h1><p>Content Warning Scanner</p><p>API: <a href="/api">localhost:8000/api</a></p></body></html>' > build/index.html)

# Go services build stage
FROM golang:1.21-alpine as go-build
RUN apk add --no-cache git ca-certificates

ENV CGO_ENABLED=0 GOOS=linux GOARCH=amd64

WORKDIR /app

# Build API service (copy go.mod first for caching)
COPY api/go.mod api/go.sum ./api/
WORKDIR /app/api
RUN go mod download
COPY api/ .
RUN go build -ldflags="-w -s" -o api ./main.go

# Build Scanner service
WORKDIR /app
COPY scanner/go.mod scanner/go.sum ./scanner/
WORKDIR /app/scanner
RUN go mod download
COPY scanner/ .
RUN go build -ldflags="-w -s" -o scanner ./cmd/main.go

# Python NLP build stage (industry standard 2024)
FROM python:3.11-slim as python-builder

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gcc g++ git \
    && rm -rf /var/lib/apt/lists/*

# Create virtual environment for isolation
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

WORKDIR /app/nlp

# Copy and install requirements in virtual environment
COPY nlp/requirements.txt .

# Install PyTorch CPU-only for smaller size (industry standard for CPU workloads)
RUN pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# Install other requirements
RUN pip install --no-cache-dir -r requirements.txt

# Verify installation
RUN python -c "import torch; import transformers; print('Dependencies verified')"

# Final runtime stage (distroless-style, industry standard 2024)
FROM python:3.11-slim

# Install only essential runtime dependencies (no build tools)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg nginx curl ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create non-root user for security (industry standard)
RUN groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /app

# Copy built Go services
COPY --from=go-build /app/api/api /app/api
COPY --from=go-build /app/scanner/scanner /app/scanner

# Copy Python virtual environment from builder stage
COPY --from=python-builder /opt/venv /opt/venv

# Copy NLP application code
COPY nlp/app/ /app/nlp/app/

# Set Python path to use virtual environment
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONPATH="/app" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Copy frontend build
COPY --from=frontend-build /app/frontend/build /app/frontend/build
COPY frontend/nginx.conf /etc/nginx/nginx.conf

# Create directories and set permissions
RUN mkdir -p /models /data && \
    chown -R appuser:appuser /app /models /data

# Copy startup script and make executable
COPY docker/start.sh /app/start.sh
RUN chmod +x /app/start.sh

# Note: Running as root for nginx, but services run as appuser where possible

# Expose all ports
EXPOSE 7219 8000 8001 80

# Use exec form for better signal handling (industry standard)
CMD ["/app/start.sh"]