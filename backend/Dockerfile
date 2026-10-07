# ==========================================
# Multi-stage Dockerfile for Fikir Go Backend
# ==========================================

# Stage 1: Build Binaries
FROM golang:1.24-alpine AS builder

WORKDIR /app

RUN apk add --no-cache git ca-certificates tzdata

COPY go.mod go.sum* ./
RUN go mod download || true

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /bin/api ./cmd/api
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /bin/worker ./cmd/worker

# Stage 2: Development with Hot-Reload (Air)
FROM golang:1.24-alpine AS dev

WORKDIR /app

RUN apk add --no-cache git curl ca-certificates tzdata
RUN go install github.com/air-verse/air@v1.61.7

COPY go.mod go.sum* ./
RUN go mod download || true

COPY . .

EXPOSE 8080

CMD ["air", "-c", ".air.toml"]

# Stage 3: Production Alpine Runtime (Non-root user)
FROM alpine:3.20 AS runner

WORKDIR /app

RUN apk --no-cache add ca-certificates tzdata curl

# Create non-root user and group
RUN addgroup -S -g 10001 appgroup && \
    adduser -S -u 10001 -G appgroup -h /app -s /bin/sh appuser

COPY --from=builder /bin/api /app/api
COPY --from=builder /bin/worker /app/worker

USER appuser

EXPOSE 8080

HEALTHCHECK --interval=10s --timeout=5s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/healthz || exit 1

CMD ["/app/api"]
