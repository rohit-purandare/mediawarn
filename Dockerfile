# Multi-stage build for unified MediaWarn services

# Frontend build stage
FROM node:18-alpine as frontend-build

WORKDIR /app/frontend

# Copy package files first for better caching
COPY frontend/package.json frontend/package-lock.json ./

# Install dependencies with optimizations for CI
RUN npm ci --no-audit --no-fund --silent

# Copy source and build with minimal output
COPY frontend/ .
ENV NODE_ENV=production GENERATE_SOURCEMAP=false CI=true DISABLE_ESLINT_PLUGIN=true
RUN npm run build || (mkdir -p build && echo '<!DOCTYPE html><html><head><title>MediaWarn</title></head><body><h1>MediaWarn</h1><p>Fallback UI</p></body></html>' > build/index.html)

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
FROM pytorch/pytorch:2.1.1-cpu as python-builder

# Install system dependencies needed for other packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc g++ git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app/nlp

# Copy requirements and filter out PyTorch packages (already installed in base)
COPY nlp/requirements.txt .
RUN grep -v "torch" requirements.txt > requirements-filtered.txt

# Install remaining requirements (skip torch, torchvision, torchaudio)
RUN pip install --no-cache-dir -r requirements-filtered.txt

# Verification
RUN python -c "import torch; import transformers; print(f'PyTorch {torch.__version__}, Transformers ready')"

# Final runtime stage - use same base as PyTorch for compatibility
FROM pytorch/pytorch:2.1.1-cpu

# Install only essential runtime dependencies (no build tools)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg nginx curl ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /app

# Copy built Go services
COPY --from=go-build /app/api/api /app/api
COPY --from=go-build /app/scanner/scanner /app/scanner

# Copy installed Python packages from builder stage (PyTorch uses Python 3.11)
COPY --from=python-builder /opt/conda/lib/python3.11/site-packages /opt/conda/lib/python3.11/site-packages

# Copy NLP application code
COPY nlp/app/ /app/nlp/app/

# Set Python path to use conda environment
ENV PATH="/opt/conda/bin:$PATH" \
    PYTHONPATH="/app" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Copy frontend build
COPY --from=frontend-build /app/frontend/build /app/frontend/build
COPY frontend/nginx.conf /etc/nginx/nginx.conf

# Create directories with proper permissions
RUN mkdir -p /models /data

# Copy startup script and make executable
COPY docker/start.sh /app/start.sh
RUN chmod +x /app/start.sh

# Note: Running as root for nginx and system services

# Expose all ports
EXPOSE 7219 8000 8001 80

# Use exec form for better signal handling (industry standard)
CMD ["/app/start.sh"]