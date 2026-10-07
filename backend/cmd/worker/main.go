package main

import (
	"context"
	"os"
	"os/signal"
	"syscall"

	"github.com/hibiken/asynq"

	"github.com/abshwabu/fikir/backend/internal/config"
	"github.com/abshwabu/fikir/backend/internal/platform/logger"
	"github.com/abshwabu/fikir/backend/internal/queue"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		panic("Failed to load worker configuration: " + err.Error())
	}

	log := logger.New(cfg.AppEnv, cfg.LogLevel)
	log.Info().Msg("Starting Fikir background worker service")

	srv := queue.NewServer(cfg.Redis, 10)
	mux := asynq.NewServeMux()

	// Handler registration for background tasks
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
