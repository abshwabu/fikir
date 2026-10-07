package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/rs/zerolog"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/abshwabu/fikir/backend/internal/config"
	apphttp "github.com/abshwabu/fikir/backend/internal/http"
)

func TestHealthEndpoints(t *testing.T) {
	cfg := &config.Config{
		AppEnv:  "test",
		AppPort: "8080",
		CORS: config.AllowedOriginsConfig{
			Origins: []string{"*"},
		},
		RateLimit: config.RateLimitConfig{
			RequestsPerMinute: 100,
			Burst:             20,
		},
	}
	nopLogger := zerolog.Nop()

	router := apphttp.NewRouter(apphttp.ServerDependencies{
		Config: cfg,
		Logger: nopLogger,
		DB:     nil,
		Redis:  nil,
	})

	endpoints := []string{"/healthz", "/api/healthz"}
	for _, ep := range endpoints {
		t.Run(ep, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, ep, nil)
			rr := httptest.NewRecorder()

			router.ServeHTTP(rr, req)

			assert.Equal(t, http.StatusOK, rr.Code)

			var body map[string]any
			err := json.Unmarshal(rr.Body.Bytes(), &body)
			require.NoError(t, err)
			assert.Equal(t, "ok", body["status"])
			assert.Equal(t, "fikir-api", body["service"])
		})
	}
}

func TestReadyzEndpoint_DegradedWhenNil(t *testing.T) {
	cfg := &config.Config{
		AppEnv:  "test",
		AppPort: "8080",
		CORS: config.AllowedOriginsConfig{
			Origins: []string{"*"},
		},
	}
	nopLogger := zerolog.Nop()

	router := apphttp.NewRouter(apphttp.ServerDependencies{
		Config: cfg,
		Logger: nopLogger,
		DB:     nil,
		Redis:  nil,
	})

	req := httptest.NewRequest(http.MethodGet, "/readyz", nil)
	rr := httptest.NewRecorder()

	router.ServeHTTP(rr, req)

	// Readyz returns 503 when dependencies are unconfigured/unreachable
	assert.Equal(t, http.StatusServiceUnavailable, rr.Code)

	var body map[string]any
	err := json.Unmarshal(rr.Body.Bytes(), &body)
	require.NoError(t, err)
	assert.NotNil(t, body["error"])
}
