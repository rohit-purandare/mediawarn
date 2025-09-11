FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    git curl ca-certificates \
    && curl -L https://go.dev/dl/go1.21.12.linux-amd64.tar.gz | tar -C /usr/local -xz \
    && rm -rf /var/lib/apt/lists/*

ENV PATH=$PATH:/usr/local/go/bin
ENV GOPROXY=https://proxy.golang.org,direct
ENV GOSUMDB=sum.golang.org

WORKDIR /app

# Copy and build with proven approach
COPY go.mod ./
RUN go mod download -x
RUN go mod tidy -v

COPY . .
RUN go build -v -o api ./main.go

EXPOSE 8000

CMD ["./api"]