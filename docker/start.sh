#!/bin/bash

# MediaWarn Multi-Service Startup Script with Structured Logging
# Handles different service configurations based on SERVICE environment variable

set -e

# Structured logging functions (JSON format for industry standard)
log_json() {
    local level="$1"
    local message="$2"
    local component="${3:-startup}"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")

    echo "{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"service\":\"mediawarn-startup\",\"component\":\"$component\",\"message\":\"$message\"}"
}

log_info() {
    log_json "INFO" "$1" "$2"
}

log_error() {
    log_json "ERROR" "$1" "$2"
}

log_debug() {
    log_json "DEBUG" "$1" "$2"
}

# Default to all services if not specified
SERVICE=${SERVICE:-all}

log_info "Starting MediaWarn services" "startup"
log_info "Service configuration: ${SERVICE}" "config"
log_info "Log level: ${LOG_LEVEL:-INFO}" "config"
log_info "Environment: ${NODE_ENV:-production}" "config"

# Ensure required directories exist
log_info "Creating required directories" "filesystem"
mkdir -p /data /models /app/config
log_info "Required directories created successfully" "filesystem"

# Function to wait for database connection with structured logging
wait_for_db() {
    log_info "Waiting for database connection" "database"
    local start_time=$(date +%s)

    for i in {1..30}; do
        if python -c "
import psycopg2
try:
    conn = psycopg2.connect('$DATABASE_URL')
    conn.close()
    exit(0)
except:
    exit(1)
" 2>/dev/null; then
            local duration=$(($(date +%s) - start_time))
            log_info "Database connection established after ${duration}s" "database"
            return 0
        fi

        if [ $i -eq 30 ]; then
            log_error "Database connection failed after 60 seconds" "database"
            exit 1
        fi

        log_debug "Database not ready, attempt $i/30" "database"
        sleep 2
    done
}

# Function to wait for redis connection with structured logging
wait_for_redis() {
    log_info "Waiting for Redis connection" "redis"
    local start_time=$(date +%s)

    for i in {1..30}; do
        if python -c "
import redis
try:
    r = redis.from_url('$REDIS_URL')
    r.ping()
    exit(0)
except:
    exit(1)
" 2>/dev/null; then
            local duration=$(($(date +%s) - start_time))
            log_info "Redis connection established after ${duration}s" "redis"
            return 0
        fi

        if [ $i -eq 30 ]; then
            log_error "Redis connection failed after 60 seconds" "redis"
            exit 1
        fi

        log_debug "Redis not ready, attempt $i/30" "redis"
        sleep 2
    done
}

# Service startup functions with structured logging
start_nginx() {
    log_info "Starting nginx for frontend on port 80" "nginx"
    nginx -g "daemon off;" &
    local pid=$!
    log_info "Nginx started with PID $pid" "nginx"
}

start_api() {
    log_info "Starting API service on port 8000" "api"
    cd /app
    export LOG_LEVEL="${LOG_LEVEL:-INFO}"
    ./api &
    local pid=$!
    log_info "API service started with PID $pid" "api"
}

start_scanner() {
    log_info "Starting Scanner service" "scanner"
    cd /app
    export LOG_LEVEL="${LOG_LEVEL:-INFO}"
    ./scanner &
    local pid=$!
    log_info "Scanner service started with PID $pid" "scanner"
}

start_nlp() {
    log_info "Starting NLP service on port 8001" "nlp"
    cd /app/nlp
    export LOG_LEVEL="${LOG_LEVEL:-INFO}"
    export APP_VERSION="${APP_VERSION:-1.0.0}"
    python -m app.main &
    local pid=$!
    log_info "NLP service started with PID $pid" "nlp"
}

# Wait for dependencies if needed
if [[ "$SERVICE" == "all" || "$SERVICE" == "api" || "$SERVICE" == "scanner" || "$SERVICE" == "nlp" ]]; then
    log_info "Checking dependencies for service: $SERVICE" "dependencies"
    wait_for_db
    wait_for_redis
    log_info "All dependencies ready" "dependencies"
fi

# Handle different service configurations with structured logging
case "$SERVICE" in
    "all")
        log_info "Starting all services in orchestrated sequence" "orchestration"

        log_info "Phase 1: Starting API service" "orchestration"
        start_api
        sleep 3  # Let API start first

        log_info "Phase 2: Starting backend services" "orchestration"
        start_scanner
        start_nlp
        sleep 2  # Let backend services stabilize

        log_info "Phase 3: Starting frontend service" "orchestration"
        start_nginx

        log_info "All services started successfully" "orchestration"
        ;;
    "api")
        log_info "Starting API service only" "orchestration"
        start_api
        ;;
    "scanner")
        log_info "Starting Scanner service only" "orchestration"
        start_scanner
        ;;
    "nlp")
        log_info "Starting NLP service only" "orchestration"
        start_nlp
        ;;
    "frontend")
        log_info "Starting Frontend service only" "orchestration"
        start_nginx
        ;;
    *)
        log_error "Unknown service: $SERVICE" "orchestration"
        log_info "Available services: all, api, scanner, nlp, frontend" "orchestration"
        exit 1
        ;;
esac

# Wait for all background processes with structured logging
log_info "All configured services started. Monitoring processes..." "monitor"

# Set up signal handlers for graceful shutdown
trap 'log_info "Received shutdown signal" "shutdown"; kill $(jobs -p); exit 0' SIGTERM SIGINT

wait