package main

import (
	"context"
	"encoding/json"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/hibiken/asynq"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"

	"github.com/abshwabu/fikir/backend/internal/cache"
	"github.com/abshwabu/fikir/backend/internal/config"
	"github.com/abshwabu/fikir/backend/internal/platform/logger"
	"github.com/abshwabu/fikir/backend/internal/platform/media"
	"github.com/abshwabu/fikir/backend/internal/platform/sms"
	"github.com/abshwabu/fikir/backend/internal/queue"
	"github.com/abshwabu/fikir/backend/internal/repository"
	"github.com/abshwabu/fikir/backend/internal/service"
	"github.com/abshwabu/fikir/backend/internal/storage"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		panic("Failed to load worker configuration: " + err.Error())
	}

	log := logger.New(cfg.AppEnv, cfg.LogLevel)
	log.Info().Msg("Starting Fikir background worker service")

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Initialize DB pool for worker tasks
	pgConfig, err := pgxpool.ParseConfig(cfg.Database.DSN())
	if err != nil {
		log.Fatal().Err(err).Msg("Failed to parse database configuration for worker")
	}
	pgConfig.MaxConns = 10
	dbPool, err := pgxpool.NewWithConfig(ctx, pgConfig)
	if err != nil {
		log.Fatal().Err(err).Msg("Failed to connect to database in worker")
	}
	defer dbPool.Close()

	// Initialize Redis for caches & worker operations
	rdb := redis.NewClient(&redis.Options{
		Addr:     cfg.Redis.Addr(),
		Password: cfg.Redis.Password,
		DB:       cfg.Redis.CacheDB,
	})
	defer func() {
		_ = rdb.Close()
	}()

	swipeCache := cache.NewSwipeCache(rdb)
	cardCache := cache.NewProfileCardCache(rdb)
	deckCache := cache.NewDeckCache(rdb)

	queries := repository.New(dbPool)
	userRepo := repository.NewUserRepository(queries)
	profileRepo := repository.NewProfileRepository(queries)
	discoveryRepo := repository.NewDiscoveryRepository(queries)
	swipeRepo := repository.NewSwipeRepository(queries)
	matchRepo := repository.NewMatchRepository(queries, dbPool, discoveryRepo)
	blockRepo := repository.NewBlockRepository(queries)
	reportRepo := repository.NewReportRepository(queries)

	smsSender := sms.NewFromConfig(cfg.SMS)

	storageClient, err := storage.New(cfg.MinIO)
	if err != nil {
		log.Fatal().Err(err).Msg("Failed to initialize storage client for worker")
	}

	queueClient := queue.NewClient(cfg.Redis)
	defer queueClient.Close()

	processor := media.NewProcessor()
	moderator := media.NewDefaultModerator(cfg.AppEnv != "production")
	mediaService := service.NewMediaService(profileRepo, storageClient, queueClient, processor, moderator, cfg.CDNBaseURL, cardCache)

	discoveryService := service.NewDiscoveryService(cfg.Discovery, discoveryRepo, profileRepo, deckCache, cardCache, swipeCache, queueClient)
	swipeService := service.NewSwipeService(cfg.Swipe, userRepo, profileRepo, swipeRepo, matchRepo, blockRepo, reportRepo, discoveryRepo, swipeCache, cardCache, queueClient)

	srv := queue.NewServer(cfg.Redis, 10)
	mux := asynq.NewServeMux()

	// Handler for SMS sending with retries
	mux.HandleFunc(queue.TypeSendSMS, func(ctx context.Context, t *asynq.Task) error {
		var payload queue.SendSMSPayload
		if err := json.Unmarshal(t.Payload(), &payload); err != nil {
			return err
		}
		log.Info().Str("to", payload.To).Msg("Dispatching SMS in worker")
		return smsSender.SendSMS(ctx, payload.To, payload.Message)
	})

	// Handler for account purge after soft delete
	mux.HandleFunc(queue.TypeAccountPurge, func(ctx context.Context, t *asynq.Task) error {
		retentionDays := 30
		var payload queue.AccountPurgePayload
		if len(t.Payload()) > 0 {
			_ = json.Unmarshal(t.Payload(), &payload)
			if payload.RetentionDays > 0 {
				retentionDays = payload.RetentionDays
			}
		}

		cutoff := time.Now().AddDate(0, 0, -retentionDays)
		purged, err := userRepo.PurgeDeleted(ctx, cutoff)
		if err != nil {
			log.Error().Err(err).Msg("Failed to purge deleted accounts")
			return err
		}
		log.Info().Int64("purged_count", purged).Time("cutoff", cutoff).Msg("Account purge completed")
		return nil
	})

	// Handler for async image processing with libvips
	mux.HandleFunc(queue.TypeImageProcess, func(ctx context.Context, t *asynq.Task) error {
		var payload queue.ImageProcessPayload
		if err := json.Unmarshal(t.Payload(), &payload); err != nil {
			log.Error().Err(err).Msg("Invalid image process task payload")
			return err
		}
		log.Info().Str("photo_id", payload.PhotoID.String()).Str("original_key", payload.OriginalKey).Msg("Processing image in worker")
		return mediaService.ProcessImage(ctx, payload.PhotoID, payload.UserID, payload.OriginalKey)
	})

	// Handler for async swipe persistence
	mux.HandleFunc(queue.TypeSwipeRecord, func(ctx context.Context, t *asynq.Task) error {
		var payload queue.SwipeRecordPayload
		if err := json.Unmarshal(t.Payload(), &payload); err != nil {
			log.Error().Err(err).Msg("Invalid swipe record task payload")
			return err
		}
		createdAt := time.Now().UTC()
		if payload.CreatedAt != "" {
			if parsed, err := time.Parse(time.RFC3339Nano, payload.CreatedAt); err == nil {
				createdAt = parsed
			}
		}
		log.Debug().
			Str("swiper_id", payload.SwiperID.String()).
			Str("target_id", payload.TargetID.String()).
			Str("direction", payload.Direction).
			Msg("Persisting swipe in worker")
		return swipeService.ProcessSwipeRecord(ctx, payload.SwiperID, payload.TargetID, payload.Direction, createdAt)
	})

	// Handler for candidate deck refill
	mux.HandleFunc(queue.TypeDeckRefill, func(ctx context.Context, t *asynq.Task) error {
		var payload queue.DeckRefillPayload
		if err := json.Unmarshal(t.Payload(), &payload); err != nil {
			log.Error().Err(err).Msg("Invalid deck refill task payload")
			return err
		}
		log.Info().Str("user_id", payload.UserID.String()).Msg("Refilling candidate deck in worker")
		return discoveryService.RefillDeck(ctx, payload.UserID)
	})

	// Handler for match notifications
	mux.HandleFunc(queue.TypeMatchNotification, func(ctx context.Context, t *asynq.Task) error {
		var payload queue.MatchNotificationPayload
		if err := json.Unmarshal(t.Payload(), &payload); err != nil {
			log.Error().Err(err).Msg("Invalid match notification task payload")
			return err
		}
		log.Info().
			Str("match_id", payload.MatchID.String()).
			Str("user_a", payload.UserA.String()).
			Str("user_b", payload.UserB.String()).
			Msg("Dispatching mutual match notification in worker")
		return nil
	})

	mux.HandleFunc(queue.TypeSendNotification, func(ctx context.Context, t *asynq.Task) error {
		log.Info().Str("type", t.Type()).Msg("Sending notification task placeholder")
		return nil
	})

	// Run asynq server in background
	go func() {
		if err := srv.Run(mux); err != nil {
			log.Fatal().Err(err).Msg("Worker server error")
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)

	<-stop
	log.Info().Msg("Shutting down worker gracefully...")

	srv.Shutdown()
	log.Info().Msg("Worker stopped")
}
