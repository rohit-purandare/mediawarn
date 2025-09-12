FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    git curl ca-certificates ffmpeg \
    && ARCH=$(dpkg --print-architecture) \
    && if [ "$ARCH" = "amd64" ]; then GOARCH="amd64"; elif [ "$ARCH" = "arm64" ]; then GOARCH="arm64"; else GOARCH="amd64"; fi \
    && curl -L https://go.dev/dl/go1.21.12.linux-${GOARCH}.tar.gz | tar -C /usr/local -xz \
    && rm -rf /var/lib/apt/lists/*

ENV PATH=$PATH:/usr/local/go/bin
ENV GOPROXY=https://proxy.golang.org,direct
ENV GOSUMDB=sum.golang.org

WORKDIR /app

# Copy source and build with working go.sum files
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN go build -v -o scanner ./cmd/main.go

EXPOSE 8080

CMD ["./scanner"]