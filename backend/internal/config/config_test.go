package config_test

import (
	"os"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/abshwabu/fikir/backend/internal/config"
)

func TestConfig_Load_Defaults(t *testing.T) {
	// Clear any overrides that might affect tests
	os.Clearenv()
	_ = os.Setenv("JWT_SECRET", "12345678901234567890123456789012")

	cfg, err := config.Load()
	require.NoError(t, err)
	require.NotNil(t, cfg)

	assert.Equal(t, "development", cfg.AppEnv)
	assert.Equal(t, "8080", cfg.AppPort)
	assert.Equal(t, "info", cfg.LogLevel)
	assert.Equal(t, "postgres", cfg.Database.Host)
	assert.Equal(t, 5432, cfg.Database.Port)
	assert.Equal(t, "fikir", cfg.Database.Name)
	assert.Equal(t, "postgres://postgres:postgres@postgres:5432/fikir?sslmode=disable", cfg.Database.DSN())
	assert.Equal(t, "redis:6379", cfg.Redis.Addr())
	assert.Equal(t, 15*time.Minute, cfg.JWT.AccessExpiry)
}

func TestConfig_Load_ValidationFailure(t *testing.T) {
	os.Clearenv()
	_ = os.Setenv("APP_ENV", "invalid_environment")
	_ = os.Setenv("JWT_SECRET", "short")

	cfg, err := config.Load()
	assert.Error(t, err)
	assert.Nil(t, cfg)
}

func TestConfig_Load_CustomOverrides(t *testing.T) {
	os.Clearenv()
	_ = os.Setenv("APP_ENV", "production")
	_ = os.Setenv("APP_PORT", "9090")
	_ = os.Setenv("DB_HOST", "db.internal")
	_ = os.Setenv("DB_PORT", "5433")
	_ = os.Setenv("JWT_SECRET", "production-secret-key-that-is-at-least-32-chars-long")

	cfg, err := config.Load()
	require.NoError(t, err)
	require.NotNil(t, cfg)

	assert.Equal(t, "production", cfg.AppEnv)
	assert.Equal(t, "9090", cfg.AppPort)
	assert.Equal(t, "db.internal", cfg.Database.Host)
	assert.Equal(t, 5433, cfg.Database.Port)
}
