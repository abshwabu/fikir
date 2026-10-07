package http

import (
	"time"

	"github.com/go-chi/chi/v5"
	chimw "github.com/go-chi/chi/v5/middleware"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
	"github.com/rs/zerolog"

	"github.com/abshwabu/fikir/backend/internal/config"
	"github.com/abshwabu/fikir/backend/internal/http/handler"
	"github.com/abshwabu/fikir/backend/internal/http/middleware"
)

// ServerDependencies contains all components needed by the router
type ServerDependencies struct {
	Config *config.Config
	Logger zerolog.Logger
	DB     *pgxpool.Pool
	Redis  *redis.Client
}

// NewRouter constructs the Chi router with middleware and routes
func NewRouter(deps ServerDependencies) *chi.Mux {
	r := chi.NewRouter()

	// Base middleware
	r.Use(middleware.RequestID)
	r.Use(chimw.RealIP)
	r.Use(middleware.StructuredLogger(deps.Logger))
	r.Use(middleware.Recoverer(deps.Logger))
	r.Use(middleware.CORS(deps.Config.CORS.Origins))
	r.Use(middleware.Compress(5))
	r.Use(middleware.Timeout(30 * time.Second))

	// Rate limiting (per IP and per user)
	if deps.Redis != nil {
		rateLimiter := middleware.NewRateLimiter(deps.Redis, deps.Logger, deps.Config.RateLimit.RequestsPerMinute)
		r.Use(rateLimiter.Handler())
	}

	// Health check handlers
	healthHandler := handler.NewHealthHandler(deps.DB, deps.Redis)

	// Liveness & Readiness endpoints
	r.Get("/healthz", healthHandler.Healthz)
	r.Get("/readyz", healthHandler.Readyz)

	// API prefixes
	r.Route("/api", func(api chi.Router) {
		api.Get("/healthz", healthHandler.Healthz)
		api.Get("/readyz", healthHandler.Readyz)

		api.Route("/v1", func(v1 chi.Router) {
			// Placeholder for future endpoints
			v1.Get("/ping", healthHandler.Healthz)
		})
	})

	return r
}
