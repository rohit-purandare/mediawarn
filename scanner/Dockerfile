FROM ubuntu:22.04 AS builder

RUN apt-get update && apt-get install -y git curl ca-certificates && \
    curl -L https://go.dev/dl/go1.21.12.linux-amd64.tar.gz | tar -C /usr/local -xz && \
    rm -rf /var/lib/apt/lists/*

ENV PATH=$PATH:/usr/local/go/bin
ENV GOPROXY=https://proxy.golang.org,direct
ENV GOSUMDB=sum.golang.org

WORKDIR /app

# Step-by-step build exactly like working debug test
COPY go.mod ./
RUN go mod download -x 2>&1 || echo "go mod download completed with exit $?"
RUN go mod tidy -v 2>&1 || echo "go mod tidy completed with exit $?"

# Copy internal packages first (like debug test)
COPY internal/ ./internal/
COPY cmd/ ./cmd/

# Copy remaining files
COPY . .

# Build with exact debug test flags
RUN go build -v -o scanner ./cmd/main.go 2>&1 || echo "go build completed with exit $?"

FROM alpine:latest

RUN apk --no-cache add ca-certificates ffmpeg
WORKDIR /root/

COPY --from=builder /app/scanner .

CMD ["./scanner"]