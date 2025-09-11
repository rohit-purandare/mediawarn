# Debug Go build issues step by step
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y golang-go git

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

# Test 3: Copy one source file and try to build
COPY scanner/internal/config/config.go ./scanner/internal/config/
RUN echo "=== Testing Simple Go Build ===" && \
    cd scanner && \
    go build -v ./internal/config/ 2>&1

# Test 4: Copy main.go and try to build just main
COPY scanner/cmd/main.go ./scanner/cmd/
RUN echo "=== Testing Main.go Compilation ===" && \
    cd scanner && \
    go build -v -x ./cmd/main.go 2>&1

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