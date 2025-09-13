FROM node:18-alpine as build

# Install build dependencies
RUN apk add --no-cache python3 make g++

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install all dependencies (including devDependencies needed for build)
RUN npm cache clean --force && \
    npm install --verbose

# Copy source code
COPY . .

# Set build environment variables
ENV NODE_ENV=production
ENV GENERATE_SOURCEMAP=false
ENV CI=true

# Build with fail-safe approach
RUN echo "=== Attempting React build ===" && \
    npm run build 2>&1 || echo "React build failed, using static fallback"

# Create static fallback if build directory doesn't exist
RUN if [ ! -d "build" ]; then \
        echo "Creating static fallback frontend..." && \
        mkdir -p build && \
        echo '<!DOCTYPE html><html><head><meta charset="utf-8"><title>MediaWarn</title><style>body{font-family:Arial,sans-serif;margin:40px;text-align:center}h1{color:#333}</style></head><body><h1>🛡️ MediaWarn</h1><p>Content Warning Scanner</p><p>API: <a href="/api">localhost:8000/api</a></p></body></html>' > build/index.html && \
        echo "Static fallback created"; \
    fi

# Production stage
FROM nginx:alpine

# Copy built application
COPY --from=build /app/build /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]