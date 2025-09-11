FROM golang:1.21-alpine AS builder

RUN apk add --no-cache git

WORKDIR /app
COPY go.mod ./
RUN go mod download && go mod verify

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o scanner ./cmd/main.go

FROM alpine:latest

RUN apk --no-cache add ca-certificates ffmpeg
WORKDIR /root/

COPY --from=builder /app/scanner .

CMD ["./scanner"]