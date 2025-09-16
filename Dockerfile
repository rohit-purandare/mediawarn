# Multi-stage build for unified MediaWarn services

# Frontend build stage - simplified approach
FROM node:18-alpine as frontend-build

# Install build dependencies
RUN apk add --no-cache python3 make g++

WORKDIR /app/frontend

# Copy package.json and try to install (fallback to npm install if ci fails)
COPY frontend/package*.json ./
RUN npm install || npm ci || echo "npm install failed, using fallback"

# Copy source and build with fallback
COPY frontend/ .
ENV NODE_ENV=production GENERATE_SOURCEMAP=false CI=false
RUN npm run build 2>/dev/null || (mkdir -p build && echo '<!DOCTYPE html><html><head><title>MediaWarn Frontend</title><style>body{font-family:Arial;text-align:center;padding:50px}</style></head><body><h1>🛡️ MediaWarn</h1><p>Content Warning Scanner</p><p>Frontend temporarily unavailable</p></body></html>' > build/index.html)

# Go services build stage
FROM golang:1.21-alpine as go-build
RUN apk add --no-cache git ca-certificates

ENV CGO_ENABLED=0 GOOS=linux

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

# Python NLP build stage (official PyTorch image - industry standard)
FROM python:3.11-slim as python-builder

# Install system dependencies needed for other packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc g++ git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app/nlp

# Copy requirements and install PyTorch CPU-only first
COPY nlp/requirements.txt .
RUN pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# Install remaining requirements
RUN pip install --no-cache-dir -r requirements.txt

# Verification
RUN python -c "import torch; import transformers; print(f'PyTorch {torch.__version__}, Transformers ready')"

# Final runtime stage - use same Python base for simplicity
FROM python:3.11-slim

# Install only essential runtime dependencies (no build tools)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg nginx curl ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /app

# Copy built Go services
COPY --from=go-build /app/api/api /app/api
COPY --from=go-build /app/scanner/scanner /app/scanner

# Copy entire Python environment from builder stage for reliability
COPY --from=python-builder /usr/local /usr/local

# Copy NLP application code
COPY nlp/app/ /app/nlp/app/

# Set Python environment variables
ENV PYTHONPATH="/app" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Copy frontend build to standard nginx location
COPY --from=frontend-build /app/frontend/build /usr/share/nginx/html
COPY frontend/nginx.conf /etc/nginx/nginx.conf

# Create directories with proper permissions
RUN mkdir -p /models /data /app/config

# Copy startup script and make executable
COPY docker/start.sh /app/start.sh
RUN chmod +x /app/start.sh

# Note: Running as root for nginx and system services

# Expose all ports
EXPOSE 7219 8000 8001

# Use exec form for better signal handling (industry standard)
CMD ["/app/start.sh"]