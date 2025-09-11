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
    exec > >(tee -a /tmp/scanner-build.log) 2>&1 && \
    echo "=== SCANNER BUILD ATTEMPT - $(date) ===" && \
    echo "Directory contents:" && \
    find . -name "*.go" && \
    echo "" && \
    echo "=== GO.MOD CONTENTS ===" && \
    cat go.mod && \
    echo "" && \
    echo "=== STEP 1: go mod download ===" && \
    go mod download -x && \
    echo "go mod download completed with exit code: $?" && \
    echo "" && \
    echo "=== STEP 2: go mod tidy ===" && \
    go mod tidy -v && \
    echo "go mod tidy completed with exit code: $?" && \
    echo "" && \
    echo "=== STEP 3: go list all packages ===" && \
    go list ./... && \
    echo "go list completed with exit code: $?" && \
    echo "" && \
    echo "=== STEP 4: go build main.go ===" && \
    go build -v -x -o scanner ./cmd/main.go && \
    echo "go build completed with exit code: $?" && \
    echo "" && \
    echo "=== BUILD VERIFICATION ===" && \
    ls -la scanner && \
    file scanner && \
    echo "SUCCESS: Scanner built and verified!" && \
    cat /tmp/scanner-build.log

# If scanner works, try API
COPY api/ ./api/
RUN cd api && \
    exec > >(tee -a /tmp/api-build.log) 2>&1 && \
    echo "=== API BUILD ATTEMPT - $(date) ===" && \
    echo "API directory contents:" && \
    find . -name "*.go" && \
    echo "" && \
    echo "=== API GO.MOD CONTENTS ===" && \
    cat go.mod && \
    echo "" && \
    echo "=== API STEP 1: go mod tidy ===" && \
    go mod tidy -v && \
    echo "API go mod tidy completed with exit code: $?" && \
    echo "" && \
    echo "=== API STEP 2: go build ===" && \
    go build -v -x -o api ./main.go && \
    echo "API go build completed with exit code: $?" && \
    echo "" && \
    echo "=== API BUILD VERIFICATION ===" && \
    ls -la api && \
    file api && \
    echo "SUCCESS: API built and verified!" && \
    echo "" && \
    echo "=== FINAL BUILD LOGS ===" && \
    echo "Scanner log:" && \
    cat /tmp/scanner-build.log && \
    echo "" && \
    echo "API log:" && \
    cat /tmp/api-build.log

CMD ["echo", "All Go services built successfully!"]