package integration

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
	"github.com/testcontainers/testcontainers-go"
	tcpostgres "github.com/testcontainers/testcontainers-go/modules/postgres"
	tcredis "github.com/testcontainers/testcontainers-go/modules/redis"
	"github.com/testcontainers/testcontainers-go/wait"
)

// Harness holds test container resources for integration tests
type Harness struct {
	PGContainer    *tcpostgres.PostgresContainer
	RedisContainer *tcredis.RedisContainer
	DB             *pgxpool.Pool
	Redis          *redis.Client
}

// SetupHarness spins up ephemeral Postgres and Redis containers for testing
func SetupHarness(ctx context.Context) (*Harness, func(), error) {
	// 1. Start Postgres testcontainer with PostGIS
	pgContainer, err := tcpostgres.Run(ctx,
		"postgis/postgis:16-3.4",
		tcpostgres.WithDatabase("fikir_test"),
		tcpostgres.WithUsername("postgres"),
		tcpostgres.WithPassword("postgres"),
		testcontainers.WithWaitStrategy(
			wait.ForLog("database system is ready to accept connections").
				WithOccurrence(2).
				WithStartupTimeout(60*time.Second),
		),
	)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to start postgres container: %w", err)
	}

	connStr, err := pgContainer.ConnectionString(ctx, "sslmode=disable")
	if err != nil {
		_ = pgContainer.Terminate(ctx)
		return nil, nil, fmt.Errorf("failed to get postgres connection string: %w", err)
	}

	dbPool, err := pgxpool.New(ctx, connStr)
	if err != nil {
		_ = pgContainer.Terminate(ctx)
		return nil, nil, fmt.Errorf("failed to connect to test postgres pool: %w", err)
	}

	// 2. Start Redis testcontainer
	redisContainer, err := tcredis.Run(ctx,
		"redis:7-alpine",
		testcontainers.WithWaitStrategy(
			wait.ForLog("Ready to accept connections").
				WithStartupTimeout(30*time.Second),
		),
	)
	if err != nil {
		dbPool.Close()
		_ = pgContainer.Terminate(ctx)
		return nil, nil, fmt.Errorf("failed to start redis container: %w", err)
	}

	redisURI, err := redisContainer.ConnectionString(ctx)
	if err != nil {
		dbPool.Close()
		_ = pgContainer.Terminate(ctx)
		_ = redisContainer.Terminate(ctx)
		return nil, nil, fmt.Errorf("failed to get redis URI: %w", err)
	}

	opt, err := redis.ParseURL(redisURI)
	if err != nil {
		dbPool.Close()
		_ = pgContainer.Terminate(ctx)
		_ = redisContainer.Terminate(ctx)
		return nil, nil, fmt.Errorf("failed to parse redis URI: %w", err)
	}
	rdb := redis.NewClient(opt)

	harness := &Harness{
		PGContainer:    pgContainer,
		RedisContainer: redisContainer,
		DB:             dbPool,
		Redis:          rdb,
	}

	cleanup := func() {
		if harness.DB != nil {
			harness.DB.Close()
		}
		if harness.Redis != nil {
			_ = harness.Redis.Close()
		}
		bgCtx := context.Background()
		if harness.PGContainer != nil {
			_ = harness.PGContainer.Terminate(bgCtx)
		}
		if harness.RedisContainer != nil {
			_ = harness.RedisContainer.Terminate(bgCtx)
		}
	}

	return harness, cleanup, nil
}

// ApplyMigrations executes migration files against the test database
func (h *Harness) ApplyMigrations(ctx context.Context) error {
	migrations := []string{
		"000001_init.up.sql",
		"000002_auth.up.sql",
		"000003_media_verification.up.sql",
		"000004_discovery_swipes.up.sql",
	}

	for _, m := range migrations {
		candidates := []string{
			filepath.Join("..", "..", "migrations", m),
			filepath.Join("migrations", m),
			filepath.Join("/app", "migrations", m),
		}

		var sqlBytes []byte
		var readErr error
		found := false
		for _, cand := range candidates {
			sqlBytes, readErr = os.ReadFile(cand)
			if readErr == nil {
				found = true
				break
			}
		}

		if !found {
			return fmt.Errorf("could not find migration file %s (last err: %v)", m, readErr)
		}

		if _, err := h.DB.Exec(ctx, string(sqlBytes)); err != nil {
			return fmt.Errorf("failed executing migration %s: %w", m, err)
		}
	}

	return nil
}
