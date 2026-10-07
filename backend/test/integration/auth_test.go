package integration_test

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/rs/zerolog"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/abshwabu/fikir/backend/internal/config"
	"github.com/abshwabu/fikir/backend/internal/domain"
	apphttp "github.com/abshwabu/fikir/backend/internal/http"
	"github.com/abshwabu/fikir/backend/internal/platform/sms"
	"github.com/abshwabu/fikir/backend/internal/platform/token"
	"github.com/abshwabu/fikir/backend/internal/repository"
	"github.com/abshwabu/fikir/backend/internal/service"
	"github.com/abshwabu/fikir/backend/test/integration"
)

func TestAuth_IntegrationSuite(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping auth integration suite in short mode")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
	defer cancel()

	harness, cleanup, err := integration.SetupHarness(ctx)
	require.NoError(t, err)
	defer cleanup()

	// 1. Run migrations
	err = harness.ApplyMigrations(ctx)
	require.NoError(t, err)

	cfg := &config.Config{
		AppEnv:   "test",
		AppPort:  "8080",
		LogLevel: "debug",
		JWT: config.JWTConfig{
			AccessExpiry:  15 * time.Minute,
			RefreshExpiry: 30 * 24 * time.Hour,
		},
		OTP: config.OTPConfig{
			Expiry:          5 * time.Minute,
			MaxAttempts:     5,
			ResendCooldown:  60 * time.Second,
			DailyPhoneLimit: 5,
			DailyIPLimit:    10,
		},
		SMS: config.SMSConfig{
			Provider: "console",
		},
		CORS: config.AllowedOriginsConfig{
			Origins: []string{"*"},
		},
		RateLimit: config.RateLimitConfig{
			RequestsPerMinute: 1000,
			Burst:             100,
		},
	}

	queries := repository.New(harness.DB)
	userRepo := repository.NewUserRepository(queries)
	authRepo := repository.NewAuthRepository(queries)
	tokenMgr, err := token.NewManager(cfg.JWT, authRepo)
	require.NoError(t, err)

	otpService := service.NewOTPService(harness.Redis, cfg.OTP)
	consoleSender := sms.NewConsoleSender()
	authService := service.NewAuthService(
		userRepo,
		authRepo,
		otpService,
		tokenMgr,
		consoleSender,
		nil, // queue client nil uses direct dispatch in test
	)

	router := apphttp.NewRouter(apphttp.ServerDependencies{
		Config:      cfg,
		Logger:      zerolog.Nop(),
		DB:          harness.DB,
		Redis:       harness.Redis,
		AuthService: authService,
		TokenMgr:    tokenMgr,
		UserRepo:    userRepo,
	})

	t.Run("OTP_Cooldown_And_Limits", func(t *testing.T) {
		phone := "0922334455"

		// First request succeeds
		reqBody, _ := json.Marshal(map[string]string{"phone": phone})
		req := httptest.NewRequest(http.MethodPost, "/v1/auth/otp/request", bytes.NewReader(reqBody))
		req.Header.Set("Content-Type", "application/json")
		rr := httptest.NewRecorder()
		router.ServeHTTP(rr, req)
		assert.Equal(t, http.StatusOK, rr.Code)

		// Second immediate request fails due to 60s cooldown (429)
		req2 := httptest.NewRequest(http.MethodPost, "/v1/auth/otp/request", bytes.NewReader(reqBody))
		req2.Header.Set("Content-Type", "application/json")
		rr2 := httptest.NewRecorder()
		router.ServeHTTP(rr2, req2)
		assert.Equal(t, http.StatusTooManyRequests, rr2.Code)

		// Daily phone cap: simulate hitting the cap by incrementing Redis counter
		phoneE164 := "+251922334455"
		_ = harness.Redis.Set(ctx, "otp:daily:phone:"+phoneE164, 5, 24*time.Hour).Err()
		_ = harness.Redis.Del(ctx, "otp:cooldown:"+phoneE164) // clear cooldown to test daily cap alone

		req3 := httptest.NewRequest(http.MethodPost, "/v1/auth/otp/request", bytes.NewReader(reqBody))
		req3.Header.Set("Content-Type", "application/json")
		rr3 := httptest.NewRecorder()
		router.ServeHTTP(rr3, req3)
		assert.Equal(t, http.StatusTooManyRequests, rr3.Code)

		// Daily IP cap: simulate hitting daily IP cap
		testIP := "192.168.1.50"
		_ = harness.Redis.Set(ctx, "otp:daily:ip:"+testIP, 10, 24*time.Hour).Err()
		reqIPBody, _ := json.Marshal(map[string]string{"phone": "0933445566"})
		req4 := httptest.NewRequest(http.MethodPost, "/v1/auth/otp/request", bytes.NewReader(reqIPBody))
		req4.Header.Set("Content-Type", "application/json")
		req4.Header.Set("X-Forwarded-For", testIP)
		rr4 := httptest.NewRecorder()
		router.ServeHTTP(rr4, req4)
		assert.Equal(t, http.StatusTooManyRequests, rr4.Code)
	})

	t.Run("OTP_MaxVerifyAttempts", func(t *testing.T) {
		phone := "0944556677"
		phoneE164 := "+251944556677"

		// Generate OTP directly
		code, _, err := otpService.GenerateAndStore(ctx, phoneE164, "127.0.0.1")
		require.NoError(t, err)

		// Attempt 4 wrong codes
		for i := 0; i < 4; i++ {
			verifyBody, _ := json.Marshal(map[string]string{"phone": phone, "code": "000000"})
			req := httptest.NewRequest(http.MethodPost, "/v1/auth/otp/verify", bytes.NewReader(verifyBody))
			req.Header.Set("Content-Type", "application/json")
			rr := httptest.NewRecorder()
			router.ServeHTTP(rr, req)
			assert.Equal(t, http.StatusUnauthorized, rr.Code)
		}

		// 5th wrong attempt should exceed max attempts and invalidate OTP
		verifyBody5, _ := json.Marshal(map[string]string{"phone": phone, "code": "000000"})
		req5 := httptest.NewRequest(http.MethodPost, "/v1/auth/otp/verify", bytes.NewReader(verifyBody5))
		req5.Header.Set("Content-Type", "application/json")
		rr5 := httptest.NewRecorder()
		router.ServeHTTP(rr5, req5)
		assert.Equal(t, http.StatusForbidden, rr5.Code)

		// Now even the correct code should fail because OTP was deleted
		verifyBodyCorrect, _ := json.Marshal(map[string]string{"phone": phone, "code": code})
		req6 := httptest.NewRequest(http.MethodPost, "/v1/auth/otp/verify", bytes.NewReader(verifyBodyCorrect))
		req6.Header.Set("Content-Type", "application/json")
		rr6 := httptest.NewRecorder()
		router.ServeHTTP(rr6, req6)
		assert.Equal(t, http.StatusForbidden, rr6.Code)
	})

	t.Run("EndToEnd_Signup_Refresh_ReuseDetection_SoftDelete", func(t *testing.T) {
		phone := "0911223344"
		phoneE164 := "+251911223344"

		// 1. Request OTP
		reqBody, _ := json.Marshal(map[string]string{"phone": phone})
		req := httptest.NewRequest(http.MethodPost, "/v1/auth/otp/request", bytes.NewReader(reqBody))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("X-Device-Fingerprint", "fp_test_device_1")
		rr := httptest.NewRecorder()
		router.ServeHTTP(rr, req)
		require.Equal(t, http.StatusOK, rr.Code)

		// Clear cooldown and generate code to capture for verification
		_ = harness.Redis.Del(ctx, "otp:cooldown:"+phoneE164)
		correctCode, _, err := otpService.GenerateAndStore(ctx, phoneE164, "127.0.0.1")
		require.NoError(t, err)

		// 2. Verify OTP with device information
		verifyPayload := map[string]interface{}{
			"phone": phone,
			"code":  correctCode,
			"device": map[string]string{
				"fcm_token": "fcm_test_token_12345",
				"platform":  "android",
			},
		}
		verifyBytes, _ := json.Marshal(verifyPayload)
		reqVerify := httptest.NewRequest(http.MethodPost, "/v1/auth/otp/verify", bytes.NewReader(verifyBytes))
		reqVerify.Header.Set("Content-Type", "application/json")
		reqVerify.Header.Set("X-Device-Fingerprint", "fp_test_device_1")
		rrVerify := httptest.NewRecorder()
		router.ServeHTTP(rrVerify, reqVerify)
		require.Equal(t, http.StatusOK, rrVerify.Code)

		var authRes service.VerifyOTPResponse
		err = json.Unmarshal(rrVerify.Body.Bytes(), &authRes)
		require.NoError(t, err)
		assert.NotEmpty(t, authRes.AccessToken)
		assert.NotEmpty(t, authRes.RefreshToken)
		assert.True(t, authRes.User.IsNewUser)
		assert.Equal(t, phoneE164, authRes.User.PhoneE164)

		initialAccessToken := authRes.AccessToken
		initialRefreshToken := authRes.RefreshToken

		// 3. Refresh tokens (rotation)
		refreshPayload := map[string]string{"refresh_token": initialRefreshToken}
		refreshBytes, _ := json.Marshal(refreshPayload)
		reqRefresh := httptest.NewRequest(http.MethodPost, "/v1/auth/refresh", bytes.NewReader(refreshBytes))
		reqRefresh.Header.Set("Content-Type", "application/json")
		rrRefresh := httptest.NewRecorder()
		router.ServeHTTP(rrRefresh, reqRefresh)
		require.Equal(t, http.StatusOK, rrRefresh.Code)

		var rotatedTokens token.TokenPair
		err = json.Unmarshal(rrRefresh.Body.Bytes(), &rotatedTokens)
		require.NoError(t, err)
		assert.NotEmpty(t, rotatedTokens.AccessToken)
		assert.NotEmpty(t, rotatedTokens.RefreshToken)
		assert.NotEqual(t, initialRefreshToken, rotatedTokens.RefreshToken)

		// 4. REUSE DETECTION: Present old refresh token again
		replayedReq := httptest.NewRequest(http.MethodPost, "/v1/auth/refresh", bytes.NewReader(refreshBytes))
		replayedReq.Header.Set("Content-Type", "application/json")
		rrReplay := httptest.NewRecorder()
		router.ServeHTTP(rrReplay, replayedReq)
		assert.Equal(t, http.StatusUnauthorized, rrReplay.Code)

		// Verify that family was revoked: rotated token should now ALSO be rejected!
		revokedPayload, _ := json.Marshal(map[string]string{"refresh_token": rotatedTokens.RefreshToken})
		reqFamilyRevoked := httptest.NewRequest(http.MethodPost, "/v1/auth/refresh", bytes.NewReader(revokedPayload))
		reqFamilyRevoked.Header.Set("Content-Type", "application/json")
		rrFamilyRevoked := httptest.NewRecorder()
		router.ServeHTTP(rrFamilyRevoked, reqFamilyRevoked)
		assert.Equal(t, http.StatusUnauthorized, rrFamilyRevoked.Code)

		// 5. Account Soft Deletion: DELETE /v1/me
		reqDelete := httptest.NewRequest(http.MethodDelete, "/v1/me", nil)
		reqDelete.Header.Set("Authorization", "Bearer "+initialAccessToken)
		rrDelete := httptest.NewRecorder()
		router.ServeHTTP(rrDelete, reqDelete)
		assert.Equal(t, http.StatusOK, rrDelete.Code)

		// Check user in database has status 'deleted' and deleted_at set
		u, err := userRepo.GetByID(ctx, authRes.User.ID)
		require.NoError(t, err)
		assert.Equal(t, domain.UserStatusDeleted, u.Status)
		assert.NotNil(t, u.DeletedAt)

		// 6. Hard purge via worker query
		// If cutoff is in the future relative to deleted_at, it purges the user
		futureCutoff := time.Now().Add(1 * time.Hour)
		purged, err := userRepo.PurgeDeleted(ctx, futureCutoff)
		assert.NoError(t, err)
		assert.Equal(t, int64(1), purged)

		purgedUser, err := userRepo.GetByID(ctx, authRes.User.ID)
		assert.NoError(t, err)
		assert.Nil(t, purgedUser)
	})

	t.Run("Logout", func(t *testing.T) {
		// Create a user and issue token
		user := &domain.User{
			PhoneE164: "+251988776655",
			Status:    domain.UserStatusActive,
			Locale:    "am",
		}
		err := userRepo.Create(ctx, user)
		require.NoError(t, err)

		pair, err := tokenMgr.IssueTokenPair(ctx, user.ID, user.PhoneE164)
		require.NoError(t, err)

		logoutPayload, _ := json.Marshal(map[string]string{"refresh_token": pair.RefreshToken})
		req := httptest.NewRequest(http.MethodPost, "/v1/auth/logout", bytes.NewReader(logoutPayload))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+pair.AccessToken)
		rr := httptest.NewRecorder()
		router.ServeHTTP(rr, req)
		assert.Equal(t, http.StatusOK, rr.Code)

		// Attempting to refresh with that token should now fail
		reqRefresh := httptest.NewRequest(http.MethodPost, "/v1/auth/refresh", bytes.NewReader(logoutPayload))
		reqRefresh.Header.Set("Content-Type", "application/json")
		rrRefresh := httptest.NewRecorder()
		router.ServeHTTP(rrRefresh, reqRefresh)
		assert.Equal(t, http.StatusUnauthorized, rrRefresh.Code)
	})
}
