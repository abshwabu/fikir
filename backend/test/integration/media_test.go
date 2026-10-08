package integration_test

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/abshwabu/fikir/backend/internal/config"
	"github.com/abshwabu/fikir/backend/internal/domain"
	apphttp "github.com/abshwabu/fikir/backend/internal/http"
	"github.com/abshwabu/fikir/backend/internal/platform/logger"
	"github.com/abshwabu/fikir/backend/internal/platform/token"
	"github.com/abshwabu/fikir/backend/internal/repository"
	"github.com/abshwabu/fikir/backend/internal/service"
	"github.com/abshwabu/fikir/backend/test/integration"
)

func TestMediaUploadFlow_Integration(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping media upload integration test in short mode")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	harness, cleanup, err := integration.SetupHarness(ctx)
	require.NoError(t, err)
	defer cleanup()

	err = harness.ApplyMigrations(ctx)
	require.NoError(t, err)

	cfg := &config.Config{
		AppEnv:  "test",
		AppPort: "8080",
		JWT: config.JWTConfig{
			Secret:        "test-super-secret-jwt-key-minimum-32-chars-long",
			AccessExpiry:  15 * time.Minute,
			RefreshExpiry: 720 * time.Hour,
		},
		MinIO: config.MinIOConfig{
			Endpoint:       "minio:9000",
			RootUser:       "minioadmin",
			RootPassword:   "miniopassword",
			BucketOriginal: "fikir-media-original",
			BucketPublic:   "fikir-media-public",
			Region:         "us-east-1",
		},
		RateLimit: config.RateLimitConfig{
			RequestsPerMinute: 1000,
		},
		CDNBaseURL: "http://localhost/media",
	}

	queries := repository.New(harness.DB)
	userRepo := repository.NewUserRepository(queries)
	authRepo := repository.NewAuthRepository(queries)
	profileRepo := repository.NewProfileRepository(queries)

	tokenMgr, err := token.NewManager(cfg.JWT, authRepo)
	require.NoError(t, err)

	// Create a test user
	testUser := &domain.User{
		ID:           uuid.New(),
		PhoneE164:    "+251911223344",
		Status:       domain.UserStatusActive,
		CreatedAt:    time.Now(),
		LastActiveAt: time.Now(),
	}
	err = userRepo.Create(ctx, testUser)
	require.NoError(t, err)

	// Generate access token
	accessToken, err := tokenMgr.GenerateAccessToken(testUser.ID, testUser.PhoneE164)
	require.NoError(t, err)

	// Construct router
	log := logger.New("test", "debug")
	router := apphttp.NewRouter(apphttp.ServerDependencies{
		Config:      cfg,
		Logger:      log,
		DB:          harness.DB,
		Redis:       harness.Redis,
		TokenMgr:    tokenMgr,
		UserRepo:    userRepo,
		ProfileRepo: profileRepo,
	})

	server := httptest.NewServer(router)
	defer server.Close()

	// 1. Initial Profile Setup
	profilePayload := map[string]any{
		"display_name": "Test User",
		"birthdate":    "1995-06-15",
		"gender":       "male",
		"interested_in": []string{"female"},
		"city":         "Bole",
	}
	body, _ := json.Marshal(profilePayload)
	req, _ := http.NewRequest(http.MethodPatch, server.URL+"/v1/me/profile", bytes.NewReader(body))
	req.Header.Set("Authorization", "Bearer "+accessToken)
	req.Header.Set("Content-Type", "application/json")
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	respBytes, _ := io.ReadAll(resp.Body)
	resp.Body.Close()
	require.Equal(t, http.StatusOK, resp.StatusCode, string(respBytes))

	var profResp apphttp_handler_ProfileResponse
	_ = json.Unmarshal(respBytes, &profResp)

	assert.Equal(t, "Addis Ababa", profResp.Region, "Bole sub-city should resolve to Addis Ababa region")
	assert.False(t, profResp.ShowMe, "Profile with 0 photos must not be discoverable (show_me=false)")

	// 2. Request Upload URL
	uploadReq := service.UploadURLRequest{
		ContentType: "image/jpeg",
		FileSize:    102400,
	}
	uBody, _ := json.Marshal(uploadReq)
	req, _ = http.NewRequest(http.MethodPost, server.URL+"/v1/me/photos/upload-url", bytes.NewReader(uBody))
	req.Header.Set("Authorization", "Bearer "+accessToken)
	req.Header.Set("Content-Type", "application/json")
	resp, err = http.DefaultClient.Do(req)
	require.NoError(t, err)
	assert.Equal(t, http.StatusOK, resp.StatusCode)

	var uploadResp service.UploadURLResponse
	_ = json.NewDecoder(resp.Body).Decode(&uploadResp)
	resp.Body.Close()

	assert.NotEqual(t, uuid.Nil, uploadResp.PhotoID)
	assert.NotEmpty(t, uploadResp.UploadURL)
	assert.Equal(t, 900, uploadResp.ExpiresIn)

	// 3. Complete Upload
	req, _ = http.NewRequest(http.MethodPost, fmt.Sprintf("%s/v1/me/photos/%s/complete", server.URL, uploadResp.PhotoID), nil)
	req.Header.Set("Authorization", "Bearer "+accessToken)
	resp, err = http.DefaultClient.Do(req)
	require.NoError(t, err)
	assert.Equal(t, http.StatusAccepted, resp.StatusCode)
	resp.Body.Close()

	// 4. Verify Photo Deletion and Discovery rule
	req, _ = http.NewRequest(http.MethodDelete, fmt.Sprintf("%s/v1/me/photos/%s", server.URL, uploadResp.PhotoID), nil)
	req.Header.Set("Authorization", "Bearer "+accessToken)
	resp, err = http.DefaultClient.Do(req)
	require.NoError(t, err)
	assert.Equal(t, http.StatusOK, resp.StatusCode)
	resp.Body.Close()

	// Verify photo count is 0 and show_me is false
	count, err := profileRepo.CountPhotos(ctx, testUser.ID)
	require.NoError(t, err)
	assert.Equal(t, 0, count)

	prof, err := profileRepo.GetByUserID(ctx, testUser.ID)
	require.NoError(t, err)
	assert.False(t, prof.ShowMe, "With 0 photos remaining, profile show_me must be false")
}

type apphttp_handler_ProfileResponse struct {
	DisplayName string `json:"display_name"`
	City        string `json:"city"`
	Region      string `json:"region"`
	ShowMe      bool   `json:"show_me"`
}
