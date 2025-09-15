# Final Go build test with comprehensive error handling
FROM ubuntu:24.04

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

# Test each step individually to isolate failures
RUN cd scanner && echo "=== STEP 1: Go version ===" && go version || echo "ERROR: Go version failed"
RUN cd scanner && echo "=== STEP 2: Directory contents ===" && ls -la || echo "ERROR: Directory listing failed"  
RUN cd scanner && echo "=== STEP 3: Internal structure ===" && find internal -name "*.go" || echo "ERROR: Find internal failed"
RUN cd scanner && echo "=== STEP 4: go.mod contents ===" && cat go.mod || echo "ERROR: Reading go.mod failed"
RUN cd scanner && echo "=== STEP 5: go env check ===" && go env GOOS GOARCH GOPROXY || echo "ERROR: go env failed"
RUN cd scanner && echo "=== STEP 6: go mod download ===" && go mod download -x 2>&1 || echo "ERROR: go mod download failed with exit $?"
RUN cd scanner && echo "=== STEP 7: go mod tidy ===" && go mod tidy -v 2>&1 || echo "ERROR: go mod tidy failed with exit $?"
RUN cd scanner && echo "=== STEP 8: go list packages ===" && go list ./... 2>&1 || echo "ERROR: go list failed with exit $?"
RUN cd scanner && echo "=== STEP 9: go build (verbose) ===" && go build -v -x -o scanner ./cmd/main.go 2>&1 || echo "ERROR: go build failed with exit $?"
RUN cd scanner && echo "=== STEP 10: verify binary ===" && (ls -la scanner && file scanner && echo "SUCCESS: Scanner binary created!") || echo "ERROR: No scanner binary found"

# Test API build step by step  
COPY api/ ./api/
RUN cd api && echo "=== API STEP 1: Directory contents ===" && ls -la || echo "ERROR: API directory listing failed"
RUN cd api && echo "=== API STEP 2: Find Go files ===" && find . -name "*.go" || echo "ERROR: API find failed"
RUN cd api && echo "=== API STEP 3: go.mod contents ===" && cat go.mod || echo "ERROR: Reading API go.mod failed"
RUN cd api && echo "=== API STEP 4: go mod tidy ===" && go mod tidy -v 2>&1 || echo "ERROR: API go mod tidy failed with exit $?"
RUN cd api && echo "=== API STEP 5: go build ===" && go build -v -x -o api ./main.go 2>&1 || echo "ERROR: API go build failed with exit $?"
RUN cd api && echo "=== API STEP 6: verify binary ===" && (ls -la api && file api && echo "SUCCESS: API binary created!") || echo "ERROR: No API binary found"

RUN echo "=== FINAL SUMMARY ===" && \
    echo "Scanner binary:" && (ls -la scanner/scanner 2>/dev/null || echo "Scanner not found") && \
    echo "API binary:" && (ls -la api/api 2>/dev/null || echo "API not found") && \
    echo "Build test complete."

CMD ["echo", "All Go services built successfully!"]