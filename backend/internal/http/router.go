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
	"github.com/abshwabu/fikir/backend/internal/platform/media"
	"github.com/abshwabu/fikir/backend/internal/platform/sms"
	"github.com/abshwabu/fikir/backend/internal/platform/token"
	"github.com/abshwabu/fikir/backend/internal/queue"
	"github.com/abshwabu/fikir/backend/internal/repository"
	"github.com/abshwabu/fikir/backend/internal/service"
	"github.com/abshwabu/fikir/backend/internal/storage"
)

// ServerDependencies contains all components needed by the router
type ServerDependencies struct {
	Config         *config.Config
	Logger         zerolog.Logger
	DB             *pgxpool.Pool
	Redis          *redis.Client
	AuthService    service.AuthService
	ProfileService service.ProfileService
	MediaService   service.MediaService
	TokenMgr       *token.Manager
	UserRepo       domain.UserRepository
	ProfileRepo    domain.ProfileRepository
	StorageClient  *storage.Storage
	QueueClient    *queue.Client
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

	// Initialize components
	authService := deps.AuthService
	tokenMgr := deps.TokenMgr
	userRepo := deps.UserRepo
	profileRepo := deps.ProfileRepo
	profileService := deps.ProfileService
	mediaService := deps.MediaService
	storageClient := deps.StorageClient

	if deps.DB != nil {
		queries := repository.New(deps.DB)
		if userRepo == nil {
			userRepo = repository.NewUserRepository(queries)
		}
		if profileRepo == nil {
			profileRepo = repository.NewProfileRepository(queries)
		}

		if storageClient == nil && deps.Config != nil {
			var err error
			storageClient, err = storage.New(deps.Config.MinIO)
			if err != nil {
				deps.Logger.Warn().Err(err).Msg("Failed to initialize storage client")
			}
		}

		if mediaService == nil && storageClient != nil && profileRepo != nil {
			processor := media.NewProcessor()
			moderator := media.NewDefaultModerator(deps.Config.AppEnv != "production")
			cdnBase := "http://localhost/media"
			if deps.Config != nil && deps.Config.CDNBaseURL != "" {
				cdnBase = deps.Config.CDNBaseURL
			}
			mediaService = service.NewMediaService(profileRepo, storageClient, deps.QueueClient, processor, moderator, cdnBase)
		}

		if profileService == nil && profileRepo != nil {
			profileService = service.NewProfileService(profileRepo, mediaService)
		}

		if authService == nil && deps.Redis != nil {
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
	}

	var authHandler *handler.AuthHandler
	if authService != nil {
		authHandler = handler.NewAuthHandler(authService)
	}

	var profileHandler *handler.ProfileHandler
	if profileService != nil && mediaService != nil {
		profileHandler = handler.NewProfileHandler(profileService, mediaService)
	}

	var mediaHandler *handler.MediaHandler
	if mediaService != nil {
		mediaHandler = handler.NewMediaHandler(mediaService)
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

				if profileHandler != nil {
					authed.Get("/me/profile", profileHandler.GetProfile)
					authed.Patch("/me/profile", profileHandler.UpdateProfile)
					authed.Put("/me/interests", profileHandler.UpdateInterests)
					authed.Put("/me/location", profileHandler.UpdateLocation)
					authed.Post("/me/verification", profileHandler.SubmitVerification)
				}

				if mediaHandler != nil {
					authed.Post("/me/photos/upload-url", mediaHandler.RequestUploadURL)
					authed.Post("/me/photos/{id}/complete", mediaHandler.CompleteUpload)
					authed.Delete("/me/photos/{id}", mediaHandler.DeletePhoto)
					authed.Put("/me/photos/reorder", mediaHandler.ReorderPhotos)
				}
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
