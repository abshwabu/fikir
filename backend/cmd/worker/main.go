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

	"github.com/abshwabu/fikir/backend/internal/config"
	"github.com/abshwabu/fikir/backend/internal/platform/logger"
	"github.com/abshwabu/fikir/backend/internal/platform/sms"
	"github.com/abshwabu/fikir/backend/internal/queue"
	"github.com/abshwabu/fikir/backend/internal/repository"
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

	userRepo := repository.NewUserRepository(repository.New(dbPool))
	smsSender := sms.NewFromConfig(cfg.SMS)

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

	// Placeholder handlers
	mux.HandleFunc(queue.TypeImageProcess, func(ctx context.Context, t *asynq.Task) error {
		log.Info().Str("type", t.Type()).Msg("Processing image task placeholder")
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
