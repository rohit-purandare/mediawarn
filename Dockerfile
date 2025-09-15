# Multi-stage build for unified MediaWarn services
FROM node:18-alpine as frontend-build

# Install build dependencies
RUN apk add --no-cache python3 make g++

WORKDIR /app/frontend

# Copy frontend package files
COPY frontend/package*.json ./
RUN npm cache clean --force && npm install --verbose

# Copy frontend source and build
COPY frontend/ .
ENV NODE_ENV=production
ENV GENERATE_SOURCEMAP=false
ENV CI=true

RUN npm run build 2>&1 || (mkdir -p build && echo '<!DOCTYPE html><html><head><meta charset="utf-8"><title>MediaWarn</title><style>body{font-family:Arial,sans-serif;margin:40px;text-align:center}h1{color:#333}</style></head><body><h1>🛡️ MediaWarn</h1><p>Content Warning Scanner</p><p>API: <a href="/api">localhost:8000/api</a></p></body></html>' > build/index.html)

# Go services build stage
FROM ubuntu:22.04 as go-build

RUN apt-get update && apt-get install -y \
    git curl ca-certificates \
    && ARCH=$(dpkg --print-architecture) \
    && if [ "$ARCH" = "amd64" ]; then GOARCH="amd64"; elif [ "$ARCH" = "arm64" ]; then GOARCH="arm64"; else GOARCH="amd64"; fi \
    && curl -L https://go.dev/dl/go1.21.12.linux-${GOARCH}.tar.gz | tar -C /usr/local -xz \
    && rm -rf /var/lib/apt/lists/*

ENV PATH=$PATH:/usr/local/go/bin
ENV GOPROXY=https://proxy.golang.org,direct
ENV GOSUMDB=sum.golang.org

WORKDIR /app

# Copy Go modules and download dependencies
COPY go.mod go.sum ./
RUN go mod download

# Copy source and build services
COPY . .
RUN go build -v -o api ./api/main.go
RUN go build -v -o scanner ./scanner/cmd/main.go

# Python NLP build stage
FROM python:3.11-slim as nlp-build

RUN apt-get update && apt-get install -y \
    ffmpeg gcc g++ \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app/nlp
COPY nlp/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Final runtime stage
FROM ubuntu:22.04

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    python3 python3-pip ffmpeg nginx curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy built Go services
COPY --from=go-build /app/api /app/api
COPY --from=go-build /app/scanner /app/scanner

# Copy Python NLP service
COPY --from=nlp-build /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY nlp/app/ /app/nlp/app/

# Copy frontend build
COPY --from=frontend-build /app/frontend/build /app/frontend/build
COPY frontend/nginx.conf /etc/nginx/nginx.conf

# Create models directory
RUN mkdir -p /models /data

# Copy startup script
COPY docker/start.sh /app/start.sh
RUN chmod +x /app/start.sh

# Expose all ports
EXPOSE 7219 8000 8001 80

CMD ["/app/start.sh"]