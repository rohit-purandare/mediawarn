# Simple Go build test
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y git curl && \
    curl -L https://go.dev/dl/go1.21.12.linux-amd64.tar.gz | tar -C /usr/local -xz && \
    export PATH=$PATH:/usr/local/go/bin

ENV PATH=$PATH:/usr/local/go/bin

WORKDIR /app

# Copy everything and try to build
COPY scanner/ ./scanner/
COPY api/ ./api/

# Try building scanner
RUN cd scanner && \
    echo "Go version: $(/usr/local/go/bin/go version)" && \
    echo "Contents:" && ls -la && \
    echo "Internal structure:" && find internal -name "*.go" && \
    echo "go.mod contents:" && cat go.mod && \
    echo "Starting go mod tidy..." && \
    /usr/local/go/bin/go mod tidy && \
    echo "Starting go build..." && \
    /usr/local/go/bin/go build -v -o scanner ./cmd/main.go && \
    echo "Scanner built successfully!"

# Try building API  
RUN cd api && \
    echo "Building API..." && \
    /usr/local/go/bin/go mod tidy && \
    /usr/local/go/bin/go build -v -o api ./main.go && \
    echo "API built successfully!"

CMD ["echo", "Both Go services built successfully!"]