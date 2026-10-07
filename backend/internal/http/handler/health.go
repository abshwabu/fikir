package handler

import (
	"context"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"

	"github.com/abshwabu/fikir/backend/internal/http/response"
	apperrors "github.com/abshwabu/fikir/backend/internal/platform/errors"
)

// HealthHandler handles health check endpoints
type HealthHandler struct {
	db  *pgxpool.Pool
	rdb *redis.Client
}

// NewHealthHandler constructs a HealthHandler
func NewHealthHandler(db *pgxpool.Pool, rdb *redis.Client) *HealthHandler {
	return &HealthHandler{
		db:  db,
		rdb: rdb,
	}
}

// Healthz responds to liveness probes
func (h *HealthHandler) Healthz(w http.ResponseWriter, r *http.Request) {
	response.OK(w, map[string]any{
		"status":    "ok",
		"service":   "fikir-api",
		"timestamp": time.Now().UTC(),
	})
}

// Readyz responds to readiness probes, verifying Postgres and Redis connections
func (h *HealthHandler) Readyz(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 3*time.Second)
	defer cancel()

	checks := map[string]string{
		"database": "ok",
		"redis":    "ok",
	}

	var hasError bool

	// Check PostgreSQL connection pool
	if h.db != nil {
		if err := h.db.Ping(ctx); err != nil {
			checks["database"] = "unreachable: " + err.Error()
			hasError = true
		}
	} else {
		checks["database"] = "not_configured"
		hasError = true
	}

	// Check Redis connection
	if h.rdb != nil {
		if err := h.rdb.Ping(ctx).Err(); err != nil {
			checks["redis"] = "unreachable: " + err.Error()
			hasError = true
		}
	} else {
		checks["redis"] = "not_configured"
		hasError = true
	}

	if hasError {
		response.Error(w, &apperrors.AppError{
			StatusCode: http.StatusServiceUnavailable,
			Code:       apperrors.CodeServiceUnavail,
			Message:    "One or more dependencies are unhealthy",
			Details: []apperrors.ErrorDetail{
				{Field: "database", Message: checks["database"]},
				{Field: "redis", Message: checks["redis"]},
			},
		})
		return
	}

	response.OK(w, map[string]any{
		"status":    "ready",
		"checks":    checks,
		"timestamp": time.Now().UTC(),
	})
}
