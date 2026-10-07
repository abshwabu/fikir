package integration_test

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/abshwabu/fikir/backend/test/integration"
)

func TestIntegrationHarness(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping integration harness test in short mode")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	harness, cleanup, err := integration.SetupHarness(ctx)
	require.NoError(t, err)
	defer cleanup()

	// Verify PostgreSQL connectivity
	err = harness.DB.Ping(ctx)
	assert.NoError(t, err)

	var result int
	err = harness.DB.QueryRow(ctx, "SELECT 1").Scan(&result)
	assert.NoError(t, err)
	assert.Equal(t, 1, result)

	// Verify Redis connectivity
	pong, err := harness.Redis.Ping(ctx).Result()
	assert.NoError(t, err)
	assert.Equal(t, "PONG", pong)
}
