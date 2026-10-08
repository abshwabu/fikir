package http

import (
	"context"
	"time"

	"github.com/go-chi/chi/v5"
	chimw "github.com/go-chi/chi/v5/middleware"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/redis/go-redis/v9"
	"github.com/rs/zerolog"

	"github.com/abshwabu/fikir/backend/internal/cache"
	"github.com/abshwabu/fikir/backend/internal/config"
	"github.com/abshwabu/fikir/backend/internal/domain"
	"github.com/abshwabu/fikir/backend/internal/http/handler"
	"github.com/abshwabu/fikir/backend/internal/http/middleware"
	"github.com/abshwabu/fikir/backend/internal/platform/media"
	"github.com/abshwabu/fikir/backend/internal/platform/safety"
	"github.com/abshwabu/fikir/backend/internal/platform/sms"
	"github.com/abshwabu/fikir/backend/internal/platform/token"
	"github.com/abshwabu/fikir/backend/internal/queue"
	"github.com/abshwabu/fikir/backend/internal/repository"
	"github.com/abshwabu/fikir/backend/internal/service"
	"github.com/abshwabu/fikir/backend/internal/storage"
	"github.com/abshwabu/fikir/backend/internal/ws"
)

// ServerDependencies contains all components needed by the router
type ServerDependencies struct {
	Config         *config.Config
	Logger         zerolog.Logger
	DB             *pgxpool.Pool
	Redis          *redis.Client
	AuthService    service.AuthService
	ProfileService   service.ProfileService
	MediaService     service.MediaService
	DiscoveryService service.DiscoveryService
	SwipeService     service.SwipeService
	TokenMgr         *token.Manager
	UserRepo         domain.UserRepository
	ProfileRepo      domain.ProfileRepository
	DiscoveryRepo    domain.DiscoveryRepository
	SwipeRepo        domain.SwipeRepository
	MatchRepo        domain.MatchRepository
	BlockRepo        domain.BlockRepository
	ReportRepo       domain.ReportRepository
	CardCache        cache.ProfileCardCache
	DeckCache        cache.DeckCache
	SwipeCache       cache.SwipeCache
	ChatCache        cache.ChatCache
	StorageClient    *storage.Storage
	QueueClient      *queue.Client
	ChatService      service.ChatService
	Hub              *ws.Hub
	ChatRepo         domain.ChatRepository
	DeviceRepo       domain.DeviceRepository
	NotifRepo        domain.NotificationRepository
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
	r.Handle("/metrics", promhttp.Handler())

	// Initialize components
	authService := deps.AuthService
	tokenMgr := deps.TokenMgr
	userRepo := deps.UserRepo
	profileRepo := deps.ProfileRepo
	profileService := deps.ProfileService
	mediaService := deps.MediaService
	storageClient := deps.StorageClient
	discoveryRepo := deps.DiscoveryRepo
	swipeRepo := deps.SwipeRepo
	matchRepo := deps.MatchRepo
	blockRepo := deps.BlockRepo
	reportRepo := deps.ReportRepo
	cardCache := deps.CardCache
	deckCache := deps.DeckCache
	swipeCache := deps.SwipeCache
	chatCache := deps.ChatCache
	chatRepo := deps.ChatRepo
	deviceRepo := deps.DeviceRepo
	notifRepo := deps.NotifRepo
	hub := deps.Hub
	chatService := deps.ChatService
	discoveryService := deps.DiscoveryService
	swipeService := deps.SwipeService

	if deps.DB != nil {
		queries := repository.New(deps.DB)
		if userRepo == nil {
			userRepo = repository.NewUserRepository(queries)
		}
		if profileRepo == nil {
			profileRepo = repository.NewProfileRepository(queries)
		}
		if discoveryRepo == nil {
			discoveryRepo = repository.NewDiscoveryRepository(queries)
		}
		if swipeRepo == nil {
			swipeRepo = repository.NewSwipeRepository(queries)
		}
		if matchRepo == nil {
			matchRepo = repository.NewMatchRepository(queries, deps.DB, discoveryRepo)
		}
		if blockRepo == nil {
			blockRepo = repository.NewBlockRepository(queries)
		}
		if reportRepo == nil {
			reportRepo = repository.NewReportRepository(queries)
		}
		if chatRepo == nil {
			chatRepo = repository.NewChatRepository(queries)
		}
		if deviceRepo == nil {
			deviceRepo = repository.NewDeviceRepository(queries)
		}
		if notifRepo == nil {
			notifRepo = repository.NewNotificationRepository(queries)
		}

		if deps.Redis != nil {
			if cardCache == nil {
				cardCache = cache.NewProfileCardCache(deps.Redis)
			}
			if deckCache == nil {
				deckCache = cache.NewDeckCache(deps.Redis)
			}
			if swipeCache == nil {
				swipeCache = cache.NewSwipeCache(deps.Redis)
			}
			if chatCache == nil {
				chatCache = cache.NewChatCache(deps.Redis)
			}
			if hub == nil {
				hub = ws.NewHub("", deps.Redis, chatCache)
				hub.Start(context.Background())
			}
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
			mediaService = service.NewMediaService(profileRepo, storageClient, deps.QueueClient, processor, moderator, cdnBase, cardCache)
		}

		if profileService == nil && profileRepo != nil {
			profileService = service.NewProfileService(profileRepo, mediaService, cardCache)
		}

		if discoveryService == nil && discoveryRepo != nil && profileRepo != nil && deckCache != nil && cardCache != nil && swipeCache != nil && deps.Config != nil {
			discoveryService = service.NewDiscoveryService(deps.Config.Discovery, discoveryRepo, profileRepo, deckCache, cardCache, swipeCache, deps.QueueClient)
		}

		if swipeService == nil && userRepo != nil && profileRepo != nil && swipeRepo != nil && matchRepo != nil && blockRepo != nil && reportRepo != nil && discoveryRepo != nil && swipeCache != nil && cardCache != nil && deps.Config != nil {
			swipeService = service.NewSwipeService(deps.Config.Swipe, userRepo, profileRepo, swipeRepo, matchRepo, blockRepo, reportRepo, discoveryRepo, swipeCache, cardCache, deps.QueueClient)
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

		if chatService == nil && chatRepo != nil && blockRepo != nil && profileRepo != nil && deviceRepo != nil && notifRepo != nil && chatCache != nil && storageClient != nil && deps.Redis != nil && deps.Config != nil {
			chatService = service.NewChatService(
				deps.Config.Chat,
				deps.Config.CDNBaseURL,
				chatRepo,
				blockRepo,
				profileRepo,
				deviceRepo,
				notifRepo,
				chatCache,
				storageClient,
				deps.QueueClient,
				deps.Redis,
				safety.NewSafetyAnalyzer(),
			)
		}
	}

	var authHandler *handler.AuthHandler
	if authService != nil {
		authHandler = handler.NewAuthHandler(authService)
	}

	var chatHandler *handler.ChatHandler
	if chatService != nil && chatCache != nil && hub != nil {
		chatHandler = handler.NewChatHandler(chatService, chatCache, hub)
	}

	var profileHandler *handler.ProfileHandler
	if profileService != nil && mediaService != nil {
		profileHandler = handler.NewProfileHandler(profileService, mediaService)
	}

	var mediaHandler *handler.MediaHandler
	if mediaService != nil {
		mediaHandler = handler.NewMediaHandler(mediaService)
	}

	var discoveryHandler *handler.DiscoveryHandler
	if discoveryService != nil {
		discoveryHandler = handler.NewDiscoveryHandler(discoveryService)
	}

	var swipeHandler *handler.SwipeHandler
	if swipeService != nil {
		swipeHandler = handler.NewSwipeHandler(swipeService)
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

				if discoveryHandler != nil {
					authed.Get("/discovery", discoveryHandler.GetDiscoveryDeck)
				}

				if swipeHandler != nil {
					authed.Post("/swipes", swipeHandler.Swipe)
					authed.Post("/swipes/rewind", swipeHandler.Rewind)
					authed.Get("/likes-you", swipeHandler.GetLikesYou)
					authed.Get("/matches", swipeHandler.GetMatches)
					authed.Delete("/matches/{id}", swipeHandler.Unmatch)
					authed.Post("/blocks", swipeHandler.Block)
					authed.Post("/reports", swipeHandler.Report)
				}

				if chatHandler != nil {
					authed.Post("/ws-ticket", chatHandler.RequestWSTicket)
					authed.Post("/matches/{id}/messages", chatHandler.SendMessage)
					authed.Get("/matches/{id}/messages", chatHandler.GetMessages)
					authed.Post("/matches/{id}/read", chatHandler.MarkRead)
					authed.Post("/matches/{id}/media/upload-url", chatHandler.RequestMediaUploadURL)
					authed.Post("/devices", chatHandler.RegisterDevice)
					authed.Delete("/devices/{token}", chatHandler.UnregisterDevice)
					authed.Get("/me/notifications/settings", chatHandler.GetNotificationSettings)
					authed.Put("/me/notifications/settings", chatHandler.UpdateNotificationSettings)
				}
			})
		}

		if chatHandler != nil {
			v1.Get("/ws", chatHandler.ServeWS)
		}
	}

	if chatHandler != nil {
		r.Get("/ws", chatHandler.ServeWS)
	}

	// Mount under /v1 and /api/v1 for reverse-proxy compatibility
	r.Route("/v1", registerV1Routes)
	r.Route("/api", func(api chi.Router) {
		api.Get("/healthz", healthHandler.Healthz)
		api.Get("/readyz", healthHandler.Readyz)
		api.Handle("/metrics", promhttp.Handler())
		if chatHandler != nil {
			api.Get("/ws", chatHandler.ServeWS)
		}
		api.Route("/v1", registerV1Routes)
	})

	return r
}
