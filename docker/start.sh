#!/bin/bash

# MediaWarn Multi-Service Startup Script
# Handles different service configurations based on SERVICE environment variable

set -e

echo "Starting MediaWarn services with SERVICE=${SERVICE}"

# Default to all services if not specified
SERVICE=${SERVICE:-all}

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

# Handle different service configurations
case "$SERVICE" in
    "all")
        echo "Starting all services..."
        start_nginx
        start_api
        start_scanner
        start_nlp
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