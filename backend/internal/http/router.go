package http

import (
	"time"

	"github.com/go-chi/chi/v5"
	chimw "github.com/go-chi/chi/v5/middleware"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
	"github.com/rs/zerolog"

	"github.com/abshwabu/fikir/backend/internal/config"
	"github.com/abshwabu/fikir/backend/internal/domain"
	"github.com/abshwabu/fikir/backend/internal/http/handler"
	"github.com/abshwabu/fikir/backend/internal/http/middleware"
	"github.com/abshwabu/fikir/backend/internal/platform/sms"
	"github.com/abshwabu/fikir/backend/internal/platform/token"
	"github.com/abshwabu/fikir/backend/internal/queue"
	"github.com/abshwabu/fikir/backend/internal/repository"
	"github.com/abshwabu/fikir/backend/internal/service"
)

// ServerDependencies contains all components needed by the router
type ServerDependencies struct {
	Config      *config.Config
	Logger      zerolog.Logger
	DB          *pgxpool.Pool
	Redis       *redis.Client
	AuthService service.AuthService
	TokenMgr    *token.Manager
	UserRepo    domain.UserRepository
	QueueClient *queue.Client
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

	// Initialize Auth components if not already provided
	authService := deps.AuthService
	tokenMgr := deps.TokenMgr
	userRepo := deps.UserRepo

	if authService == nil && deps.DB != nil && deps.Redis != nil {
		queries := repository.New(deps.DB)
		if userRepo == nil {
			userRepo = repository.NewUserRepository(queries)
		}
		authRepo := repository.NewAuthRepository(queries)
		otpService := service.NewOTPService(deps.Redis, deps.Config.OTP)

		if tokenMgr == nil {
			var err error
			tokenMgr, err = token.NewManager(deps.Config.JWT, authRepo)
			if err != nil {
				deps.Logger.Fatal().Err(err).Msg("Failed to initialize token manager")
			}
		}

		smsSender := sms.NewFromConfig(deps.Config.SMS)
		authService = service.NewAuthService(
			userRepo,
			authRepo,
			otpService,
			tokenMgr,
			smsSender,
			deps.QueueClient,
		)
	}

	var authHandler *handler.AuthHandler
	if authService != nil {
		authHandler = handler.NewAuthHandler(authService)
	}

	registerV1Routes := func(v1 chi.Router) {
		v1.Get("/ping", healthHandler.Healthz)

		if authHandler != nil && tokenMgr != nil && userRepo != nil {
			v1.Route("/auth", func(auth chi.Router) {
				auth.Post("/otp/request", authHandler.RequestOTP)
				auth.Post("/otp/verify", authHandler.VerifyOTP)
				auth.Post("/refresh", authHandler.Refresh)
				auth.Post("/logout", authHandler.Logout)
			})

			// Authenticated endpoints
			v1.Group(func(authed chi.Router) {
				authed.Use(middleware.Auth(tokenMgr, userRepo, deps.Redis))
				authed.Delete("/me", authHandler.DeleteAccount)
			})
		}
	}

	// Mount under /v1 and /api/v1 for reverse-proxy compatibility
	r.Route("/v1", registerV1Routes)
	r.Route("/api", func(api chi.Router) {
		api.Get("/healthz", healthHandler.Healthz)
		api.Get("/readyz", healthHandler.Readyz)
		api.Route("/v1", registerV1Routes)
	})

	return r
}
