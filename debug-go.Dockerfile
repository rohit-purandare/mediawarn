# Debug Go build issues step by step
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y git curl && \
    # Install a newer version of Go
    curl -L https://go.dev/dl/go1.21.12.linux-amd64.tar.gz | tar -C /usr/local -xz && \
    ln -sf /usr/local/go/bin/go /usr/bin/go && \
    ln -sf /usr/local/go/bin/gofmt /usr/bin/gofmt && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Test 1: Basic Go installation
RUN echo "=== Testing Go Installation ===" && \
    go version && \
    go env GOOS && \
    go env GOARCH && \
    go env GOPATH && \
    go env GOROOT

# Test 2: Copy just the scanner go.mod and see if we can download deps
COPY scanner/go.mod ./scanner/
RUN echo "=== Testing Go Module Download ===" && \
    cd scanner && \
    cat go.mod && \
    echo "Downloading dependencies..." && \
    go mod download -x 2>&1

# Test 3: Copy all internal packages and test go mod tidy
COPY scanner/internal/ ./scanner/internal/
RUN echo "=== Testing Go Mod Tidy ===" && \
    cd scanner && \
    echo "Checking go.mod:" && \
    cat go.mod && \
    echo "Running go mod tidy with verbose output..." && \
    go mod tidy -v 2>&1 || echo "go mod tidy failed with exit code $?"

# Test 4: Copy main.go and try to build 
COPY scanner/cmd/ ./scanner/cmd/
RUN echo "=== Testing Main.go Compilation ===" && \
    cd scanner && \
    echo "Files in cmd:" && \
    ls -la cmd/ && \
    echo "Trying to build main..." && \
    go build -v -x -o test-scanner ./cmd/main.go 2>&1

# Test 5: Copy all scanner files and try full build  
COPY scanner/ ./scanner/
RUN echo "=== Testing Full Scanner Build ===" && \
    cd scanner && \
    ls -la && \
    ls -la internal/ && \
    ls -la cmd/ && \
    go mod tidy -v && \
    go build -v -x -o scanner ./cmd/main.go 2>&1

CMD ["echo", "Debug complete"]