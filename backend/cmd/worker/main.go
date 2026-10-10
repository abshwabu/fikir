package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/google/uuid"
	"github.com/hibiken/asynq"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"

	"github.com/abshwabu/fikir/backend/internal/cache"
	"github.com/abshwabu/fikir/backend/internal/config"
	"github.com/abshwabu/fikir/backend/internal/domain"
	"github.com/abshwabu/fikir/backend/internal/platform/logger"
	"github.com/abshwabu/fikir/backend/internal/platform/media"
	paymentplatform "github.com/abshwabu/fikir/backend/internal/platform/payment"
	"github.com/abshwabu/fikir/backend/internal/platform/push"
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
	swipeService := service.NewSwipeService(cfg.Swipe, userRepo, profileRepo, swipeRepo, matchRepo, blockRepo, reportRepo, discoveryRepo, swipeCache, cardCache, deckCache, queueClient)

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

	chatCache := cache.NewChatCache(rdb)
	deviceRepo := repository.NewDeviceRepository(queries)
	notifRepo := repository.NewNotificationRepository(queries)
	pushNotifier := push.NewNotifier(ctx, cfg.FCM)

	dispatchPush := func(ctx context.Context, recipientID uuid.UUID, category, senderName, snippet, collapseKey string, data map[string]string) {
		settings, locale, err := notifRepo.GetUserNotificationSettings(ctx, recipientID)
		if err != nil {
			return
		}

		if category == push.CategoryNewMatch && !settings.NewMatch {
			return
		}
		if category == push.CategoryNewMessage && !settings.NewMessage {
			return
		}
		if category == push.CategorySuperLike && !settings.SuperLike {
			return
		}

		devices, err := deviceRepo.GetActiveDevicesForUser(ctx, recipientID)
		if err != nil || len(devices) == 0 {
			return
		}

		tokens := make([]string, len(devices))
		for i, d := range devices {
			tokens[i] = d.FCMToken
		}

		title, body := push.FormatPush(category, locale, senderName, snippet)
		_ = pushNotifier.Send(ctx, &push.NotificationMessage{
			Tokens:      tokens,
			Category:    category,
			Title:       title,
			Body:        body,
			CollapseKey: collapseKey,
			Data:        data,
		})
	}

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

		// 1. Publish match.new real-time frame to both users
		matchFrame := &domain.WSFrame{
			Type:    domain.FrameTypeMatchNew,
			MatchID: &payload.MatchID,
		}
		if frameBytes, err := json.Marshal(matchFrame); err == nil {
			_ = rdb.Publish(ctx, fmt.Sprintf("chat:user:%s", payload.UserA.String()), frameBytes).Err()
			_ = rdb.Publish(ctx, fmt.Sprintf("chat:user:%s", payload.UserB.String()), frameBytes).Err()
		}

		// 2. Offline push to User A
		onlineA, _ := chatCache.IsUserOnline(ctx, payload.UserA)
		if !onlineA {
			pB, _ := profileRepo.GetByUserID(ctx, payload.UserB)
			nameB := "Someone"
			if pB != nil && pB.DisplayName != "" {
				nameB = pB.DisplayName
			}
			dispatchPush(ctx, payload.UserA, push.CategoryNewMatch, nameB, "", fmt.Sprintf("match_%s", payload.MatchID), map[string]string{"match_id": payload.MatchID.String()})
		}

		// 3. Offline push to User B
		onlineB, _ := chatCache.IsUserOnline(ctx, payload.UserB)
		if !onlineB {
			pA, _ := profileRepo.GetByUserID(ctx, payload.UserA)
			nameA := "Someone"
			if pA != nil && pA.DisplayName != "" {
				nameA = pA.DisplayName
			}
			dispatchPush(ctx, payload.UserB, push.CategoryNewMatch, nameA, "", fmt.Sprintf("match_%s", payload.MatchID), map[string]string{"match_id": payload.MatchID.String()})
		}

		return nil
	})

	// Handler for chat message push notifications (recipient offline)
	mux.HandleFunc(queue.TypeChatMessageNotification, func(ctx context.Context, t *asynq.Task) error {
		var payload queue.ChatMessageNotificationPayload
		if err := json.Unmarshal(t.Payload(), &payload); err != nil {
			log.Error().Err(err).Msg("Invalid chat message notification task payload")
			return err
		}

		online, _ := chatCache.IsUserOnline(ctx, payload.RecipientID)
		if online {
			return nil
		}

		dispatchPush(ctx, payload.RecipientID, push.CategoryNewMessage, payload.SenderName, payload.TextSnippet, fmt.Sprintf("match_%s", payload.MatchID.String()), map[string]string{
			"match_id":   payload.MatchID.String(),
			"message_id": fmt.Sprintf("%d", payload.MessageID),
		})
		return nil
	})

	// Handler for super-like notifications
	mux.HandleFunc(queue.TypeSuperLikeNotification, func(ctx context.Context, t *asynq.Task) error {
		var payload queue.SuperLikeNotificationPayload
		if err := json.Unmarshal(t.Payload(), &payload); err != nil {
			log.Error().Err(err).Msg("Invalid super like notification task payload")
			return err
		}

		dispatchPush(ctx, payload.RecipientID, push.CategorySuperLike, payload.SenderName, "", fmt.Sprintf("superlike_%s", payload.SenderID.String()), map[string]string{
			"sender_id": payload.SenderID.String(),
		})
		return nil
	})

	mux.HandleFunc(queue.TypeSendNotification, func(ctx context.Context, t *asynq.Task) error {
		log.Info().Str("type", t.Type()).Msg("Sending notification task placeholder")
		return nil
	})

	// Payment Reconciliation & Expiry worker components
	paymentRepo := repository.NewPaymentRepository(dbPool)
	chapaProv := paymentplatform.NewChapaProvider(paymentplatform.ChapaConfig{
		BaseURL:       cfg.Chapa.BaseURL,
		SecretKey:     cfg.Chapa.SecretKey,
		WebhookSecret: cfg.Chapa.WebhookSecret,
	})
	telebirrProv := paymentplatform.NewTelebirrProvider(paymentplatform.TelebirrConfig{})
	googlePlayProv := paymentplatform.NewGooglePlayProvider(paymentplatform.GooglePlayConfig{})
	paymentProviders := map[string]paymentplatform.PaymentProvider{
		"chapa":       chapaProv,
		"telebirr":    telebirrProv,
		"google_play": googlePlayProv,
	}
	paymentService := service.NewPaymentService(paymentRepo, userRepo, deviceRepo, paymentProviders, pushNotifier)

	mux.HandleFunc(queue.TypePaymentReconcile, func(ctx context.Context, t *asynq.Task) error {
		log.Info().Msg("Executing payment reconciliation task")
		count, err := paymentService.ReconcilePendingPayments(ctx)
		if err != nil {
			log.Error().Err(err).Msg("Payment reconciliation failed")
			return err
		}
		log.Info().Int("reconciled", count).Msg("Reconciliation complete")
		return nil
	})

	mux.HandleFunc(queue.TypeSubscriptionExpiry, func(ctx context.Context, t *asynq.Task) error {
		log.Info().Msg("Executing subscription expiry and reminder task")
		count, err := paymentService.ProcessExpiringSubscriptions(ctx)
		if err != nil {
			log.Error().Err(err).Msg("Subscription expiry processing failed")
			return err
		}
		log.Info().Int("reminders_sent", count).Msg("Subscription expiry check complete")
		return nil
	})

	// Run periodic background reconciliation and expiry ticker
	go func() {
		reconcileTicker := time.NewTicker(10 * time.Minute)
		expiryTicker := time.NewTicker(30 * time.Minute)
		defer reconcileTicker.Stop()
		defer expiryTicker.Stop()

		for {
			select {
			case <-ctx.Done():
				return
			case <-reconcileTicker.C:
				count, err := paymentService.ReconcilePendingPayments(ctx)
				if err != nil {
					log.Error().Err(err).Msg("Background payment reconciliation failed")
				} else if count > 0 {
					log.Info().Int("reconciled", count).Msg("Background payment reconciliation succeeded")
				}
			case <-expiryTicker.C:
				count, err := paymentService.ProcessExpiringSubscriptions(ctx)
				if err != nil {
					log.Error().Err(err).Msg("Background subscription expiry processing failed")
				} else if count > 0 {
					log.Info().Int("reminded", count).Msg("Background subscription expiry reminders dispatched")
				}
			}
		}
	}()

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
