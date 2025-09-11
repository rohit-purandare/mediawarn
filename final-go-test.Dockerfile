# Final Go build test with comprehensive error handling
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y git curl ca-certificates && \
    curl -L https://go.dev/dl/go1.21.12.linux-amd64.tar.gz | tar -C /usr/local -xz && \
    rm -rf /var/lib/apt/lists/*

ENV PATH=$PATH:/usr/local/go/bin
ENV GOPROXY=https://proxy.golang.org,direct
ENV GOSUMDB=sum.golang.org

WORKDIR /app

# Test connectivity and Go setup
RUN go version && \
    echo "GOPATH: $(go env GOPATH)" && \
    echo "GOROOT: $(go env GOROOT)" && \
    echo "GOPROXY: $(go env GOPROXY)" && \
    curl -s https://proxy.golang.org && echo "Proxy reachable"

# Copy scanner and try step by step
COPY scanner/ ./scanner/

RUN cd scanner && \
    echo "=== SCANNER BUILD ATTEMPT ===" && \
    echo "Directory contents:" && \
    find . -name "*.go" | head -10 && \
    echo "" && \
    echo "go.mod contents:" && \
    cat go.mod && \
    echo "" && \
    echo "Step 1: go mod download" && \
    (go mod download -x 2>&1 | head -20) && \
    echo "" && \
    echo "Step 2: go mod tidy" && \
    (go mod tidy -v 2>&1 | head -20) && \
    echo "" && \
    echo "Step 3: go list all" && \
    (go list ./... 2>&1 | head -10) && \
    echo "" && \
    echo "Step 4: go build" && \
    (go build -v -o scanner ./cmd/main.go 2>&1 | head -50) && \
    ls -la scanner && \
    echo "SUCCESS: Scanner built!"

# If scanner works, try API
COPY api/ ./api/
RUN cd api && \
    echo "=== API BUILD ATTEMPT ===" && \
    go mod tidy && \
    go build -v -o api ./main.go && \
    ls -la api && \
    echo "SUCCESS: API built!"

CMD ["echo", "All Go services built successfully!"]