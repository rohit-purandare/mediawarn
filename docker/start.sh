#!/bin/bash

# MediaWarn Multi-Service Startup Script
# Handles different service configurations based on SERVICE environment variable

set -e

echo "Starting MediaWarn services with SERVICE=${SERVICE}"

# Default to all services if not specified
SERVICE=${SERVICE:-all}

# Function to wait for database connection
wait_for_db() {
    echo "Waiting for database connection..."
    for i in {1..30}; do
        if python -c "
import psycopg2
try:
    conn = psycopg2.connect('$DATABASE_URL')
    conn.close()
    print('Database connected')
    exit(0)
except:
    print('Database not ready, retrying...')
    exit(1)
" 2>/dev/null; then
            break
        fi
        sleep 2
    done
}

# Function to wait for redis connection
wait_for_redis() {
    echo "Waiting for redis connection..."
    for i in {1..30}; do
        if python -c "
import redis
try:
    r = redis.from_url('$REDIS_URL')
    r.ping()
    print('Redis connected')
    exit(0)
except:
    print('Redis not ready, retrying...')
    exit(1)
" 2>/dev/null; then
            break
        fi
        sleep 2
    done
}

# Function to start nginx for frontend
start_nginx() {
    echo "Starting nginx for frontend..."
    nginx -g "daemon off;" &
}

# Function to start API service
start_api() {
    echo "Starting API service on port 8000..."
    cd /app && ./api &
}

# Function to start Scanner service
start_scanner() {
    echo "Starting Scanner service..."
    cd /app && ./scanner &
}

# Function to start NLP service
start_nlp() {
    echo "Starting NLP service on port 8001..."
    cd /app/nlp && python -m app.main &
}

# Wait for dependencies if needed
if [[ "$SERVICE" == "all" || "$SERVICE" == "api" || "$SERVICE" == "scanner" || "$SERVICE" == "nlp" ]]; then
    wait_for_db
    wait_for_redis
fi

# Handle different service configurations
case "$SERVICE" in
    "all")
        echo "Starting all services..."
        start_api
        sleep 3  # Let API start first
        start_scanner
        start_nlp
        sleep 2  # Let backend services stabilize
        start_nginx
        ;;
    "api")
        echo "Starting API service only..."
        start_api
        ;;
    "scanner")
        echo "Starting Scanner service only..."
        start_scanner
        ;;
    "nlp")
        echo "Starting NLP service only..."
        start_nlp
        ;;
    "frontend")
        echo "Starting Frontend service only..."
        start_nginx
        ;;
    *)
        echo "Unknown service: $SERVICE"
        echo "Available services: all, api, scanner, nlp, frontend"
        exit 1
        ;;
esac

# Wait for all background processes
echo "All services started. Waiting for processes..."
wait