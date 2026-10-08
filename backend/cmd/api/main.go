package main

import (
	"context"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"

	"github.com/abshwabu/fikir/backend/internal/config"
	apphttp "github.com/abshwabu/fikir/backend/internal/http"
	"github.com/abshwabu/fikir/backend/internal/platform/logger"
	"github.com/abshwabu/fikir/backend/internal/platform/metrics"
	"github.com/abshwabu/fikir/backend/internal/platform/tracing"
	"github.com/abshwabu/fikir/backend/internal/queue"
)

func main() {
	// 1. Load and validate configuration
	cfg, err := config.Load()
	if err != nil {
		panic("Failed to load configuration: " + err.Error())
	}

	// 2. Initialize structured logging
	log := logger.New(cfg.AppEnv, cfg.LogLevel)
	log.Info().Str("env", cfg.AppEnv).Str("port", cfg.AppPort).Msg("Starting Fikir API service")

	// Initialize OpenTelemetry tracer
	_, otelCleanup := tracing.InitTracer("fikir-api")
	defer func() {
		_ = otelCleanup(context.Background())
	}()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// 3. Connect to PostgreSQL
	pgConfig, err := pgxpool.ParseConfig(cfg.Database.DSN())
	if err != nil {
		log.Fatal().Err(err).Msg("Failed to parse database configuration")
	}
	pgConfig.MaxConns = cfg.Database.MaxConns
	pgConfig.MinConns = cfg.Database.MinConns
	pgConfig.MaxConnIdleTime = 5 * time.Minute
	pgConfig.MaxConnLifetime = 30 * time.Minute

	dbPool, err := pgxpool.NewWithConfig(ctx, pgConfig)
	if err != nil {
		log.Fatal().Err(err).Msg("Failed to connect to database pool")
	}
	defer dbPool.Close()

	// Start DBPool metrics sampler
	metrics.StartDBPoolMetricsCollector(ctx, dbPool, 5*time.Second)

	// 4. Connect to Redis
	rdb := redis.NewClient(&redis.Options{
		Addr:     cfg.Redis.Addr(),
		Password: cfg.Redis.Password,
		DB:       cfg.Redis.CacheDB,
	})
	defer func() {
		_ = rdb.Close()
	}()

	// 5. Connect to Asynq queue
	queueClient := queue.NewClient(cfg.Redis)
	defer func() {
		_ = queueClient.Close()
	}()

	// 6. Construct router and dependencies
	router := apphttp.NewRouter(apphttp.ServerDependencies{
		Config:      cfg,
		Logger:      log,
		DB:          dbPool,
		Redis:       rdb,
		QueueClient: queueClient,
	})

	server := &http.Server{
		Addr:         ":" + cfg.AppPort,
		Handler:      router,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// 7. Graceful shutdown listening
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)

	go func() {
		log.Info().Msgf("Server listening on http://0.0.0.0:%s", cfg.AppPort)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal().Err(err).Msg("HTTP server error")
		}
	}()

	<-stop
	log.Info().Msg("Shutting down server gracefully...")

	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer shutdownCancel()

	if err := server.Shutdown(shutdownCtx); err != nil {
		log.Error().Err(err).Msg("Server forced shutdown")
	}

	log.Info().Msg("Server stopped successfully")
}
