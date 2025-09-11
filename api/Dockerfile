FROM ubuntu:22.04 AS builder

RUN apt-get update && apt-get install -y git curl ca-certificates && \
    curl -L https://go.dev/dl/go1.21.12.linux-amd64.tar.gz | tar -C /usr/local -xz && \
    rm -rf /var/lib/apt/lists/*

ENV PATH=$PATH:/usr/local/go/bin
ENV GOPROXY=https://proxy.golang.org,direct
ENV GOSUMDB=sum.golang.org

WORKDIR /app

# Build with api directory as context
COPY go.mod ./
RUN go mod download -x 2>&1 || echo "go mod download completed with exit $?"
RUN go mod tidy -v 2>&1 || echo "go mod tidy completed with exit $?"

# Copy all source files since context is ./api
COPY . .

# Build with same approach as debug test
RUN go build -v -o api ./main.go 2>&1 || echo "go build completed with exit $?"

FROM alpine:latest

RUN apk --no-cache add ca-certificates
WORKDIR /root/

COPY --from=builder /app/api .

EXPOSE 8000

CMD ["./api"]